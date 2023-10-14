// SPDX-License-Identifier: UNLICENSED 

pragma solidity >=0.8.2 <0.9.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract MoneyMates is Initializable, Ownable2StepUpgradeable {

    address public protocolFeeDestination;

    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    uint256 public refFeePercent;

    uint256 public max_trade_size;

    bool public initialized;

    event Trade(address indexed trader, address indexed subject, bool indexed isBuy, uint256 shareAmount, uint256 ethAmount, uint256 protocolEthAmount, uint256 subjectEthAmount, uint256 refEthAmount, uint256 supply);
    event Signup(address indexed subject, address indexed referrer);
    event NewReferral(address indexed referrer, address indexed referred, uint256 referredCount);
    event ProtocolFeeUpdate(uint256 oldValue, uint256 newValue);
    event SubjectFeeUpdate(uint256 oldValue, uint256 newValue);
    event ReferralFeeUpdate(uint256 oldValue, uint256 newValue);
    event FeeRecipientUpdate(address indexed feeRecipient);
    event MaxTradeSizeUpdate(uint256 oldValue, uint256 newValue);

    struct UserInfo {
        address referrer;
        uint256 referredCount;
        bool active;
    }

    // SharesSubject => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(address => uint256) public sharesSupply;

    // User => UserInfo
    mapping(address => UserInfo) public refs;

    function initialize(address _feeDestination) public initializer {
        // FIX: HAL-09
        require(_feeDestination != address(0), 'ZERO_ADDRESS');
        // FIX: HAL-07, HAL-10
        __Ownable_init(msg.sender);
        refs[msg.sender].active = true;
        protocolFeeDestination = _feeDestination;
        protocolFeePercent = 45000000000000000; // 0.045
        subjectFeePercent = 45000000000000000; // 0.045
        refFeePercent = 10000000000000000; // 0.01
        max_trade_size = 10;
        initialized = true;
    }

    function setFeeDestination(address _feeDestination) public onlyOwner {
        // FIX: HAL-09
        require(_feeDestination != address(0), 'ZERO_ADDRESS');
        protocolFeeDestination = _feeDestination;
        emit FeeRecipientUpdate(_feeDestination);
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        // FIX: HAL-08
        require(_feePercent + subjectFeePercent + refFeePercent <= 150000000000000000, 'FEES_OVERFLOW');
        emit ProtocolFeeUpdate(protocolFeePercent, _feePercent);
        protocolFeePercent = _feePercent;
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        // FIX: HAL-08
        require(_feePercent + protocolFeePercent + refFeePercent <= 150000000000000000, 'FEES_OVERFLOW');
        emit SubjectFeeUpdate(subjectFeePercent, _feePercent);
        subjectFeePercent = _feePercent;
    }

    function setRefFeePercent(uint256 _feePercent) public onlyOwner {
        // FIX: HAL-08
        require(_feePercent + protocolFeePercent + subjectFeePercent <= 150000000000000000, 'FEES_OVERFLOW');
        emit ReferralFeeUpdate(refFeePercent, _feePercent);
        refFeePercent = _feePercent;
    }

    function setMaxTradeSize(uint256 _maxTradeSize) public onlyOwner {
        require(_maxTradeSize > 0, 'max trade size cannot be zero');
        emit MaxTradeSizeUpdate(max_trade_size, _maxTradeSize);
        max_trade_size = _maxTradeSize;
    }

    function getTotalFeePercent() public view returns(uint256) {
        return protocolFeePercent + subjectFeePercent + refFeePercent;
    }

    function getPrice(uint256 supply, uint256 amount) public pure returns (uint256) {
        uint256 sum1 = supply == 0 ? 0 : (supply - 1 )* (supply) * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = supply == 0 && amount == 1 ? 0 : (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6;
        uint256 summation = sum2 - sum1;
        return summation * 1 ether / 16000;
    }

    function getBuyPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject], amount);
    }

    function getSellPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject] - amount, amount);
    }

    function getBuyPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
        uint256 price = getBuyPrice(sharesSubject, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 refFee = price * refFeePercent / 1 ether;
        return price + protocolFee + subjectFee + refFee;
    }

    function getSellPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
        uint256 price = getSellPrice(sharesSubject, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 refFee = price * refFeePercent / 1 ether;
        return price - protocolFee - subjectFee - refFee;
    }

    function signup(address referrer) public {
        require(refs[msg.sender].active == false, "Already signed up");
        require(refs[referrer].active == true, "Referrer does not exists");
        refs[msg.sender].active = true;
        refs[msg.sender].referrer = referrer;
        refs[msg.sender].referredCount = 0;
        refs[referrer].referredCount += 1;
        emit Signup(msg.sender, referrer);
        emit NewReferral(referrer, msg.sender, refs[referrer].referredCount);
    }

    function buyShares(address sharesSubject, uint256 amount) public payable {
        require(initialized == true, 'NOT_INITIALIZED_YET');
        require(amount > 0, 'ZERO_AMOUNT');
        require(refs[msg.sender].active == true, "Signup first");
        require(amount < max_trade_size, 'MAX_AMOUNT');
        address ref = refs[msg.sender].referrer;
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > 0 || sharesSubject == msg.sender, "Only the shares' subject can buy the first share");
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 refFee = price * refFeePercent / 1 ether;
        // FIX: HAL-01
        require(msg.value >= price + protocolFee + subjectFee + refFee, "Insufficient payment");
        // FIX: HAL-03
        uint256 rest = 0;
        bool success4 = true;
        if(msg.value > price + protocolFee + subjectFee + refFee){
            rest = msg.value - price - protocolFee - subjectFee - refFee;
        }
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] + amount;
        sharesSupply[sharesSubject] = supply + amount;
        emit Trade(msg.sender, sharesSubject, true, amount, price, protocolFee, subjectFee, refFee, supply + amount);
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = sharesSubject.call{value: subjectFee}("");
        (bool success3, ) = ref.call{value: refFee}("");
        // FIX: HAL-06
        if(!success2){
            (success2, ) = protocolFeeDestination.call{value: subjectFee}("");
        }
        // FIX: HAL-06
        if(!success3){
            (success3, ) = protocolFeeDestination.call{value: refFee}("");
        }
        // FIX: HAL-03
        if(rest > 0){
            (success4, ) = protocolFeeDestination.call{value: rest}("");
        }
        require(success1 && success2 && success3 && success4, "Unable to send funds");
    }

    function sellShares(address sharesSubject, uint256 amount, uint256 sellMinPrice) public payable {
        require(initialized == true, 'NOT_INITIALIZED_YET');
        require(amount > 0, 'ZERO_AMOUNT');
        require(amount < max_trade_size, 'MAX_AMOUNT');
        require(refs[msg.sender].active == true, "Signup first");
        address ref = refs[msg.sender].referrer;
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 refFee = price * refFeePercent / 1 ether;
        // FIX: HAL-04
        require(price - protocolFee - subjectFee - refFee >= sellMinPrice, 'Slippage too high');
        require(sharesBalance[sharesSubject][msg.sender] >= amount, "Insufficient shares");
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] - amount;
        sharesSupply[sharesSubject] = supply - amount;
        emit Trade(msg.sender, sharesSubject, false, amount, price, protocolFee, subjectFee, refFee, supply - amount);
        // FIX: HAL-02
        (bool success1, ) = msg.sender.call{value: price - protocolFee - subjectFee - refFee}("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = sharesSubject.call{value: subjectFee}("");
        // FIX: HAL-06
        if(!success3){
            (success3, ) = protocolFeeDestination.call{value: subjectFee}("");
        }

        (bool success4, ) = ref.call{value: refFee}("");
        // FIX: HAL-06
        if(!success4){
            (success4, ) = protocolFeeDestination.call{value: refFee}("");
        }
        require(success1 && success2 && success3 && success4, "Unable to send funds");
    }

}