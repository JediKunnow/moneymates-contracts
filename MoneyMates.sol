// SPDX-License-Identifier: UNLICENSED 

pragma solidity >=0.8.2 <0.9.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MoneyMates is Initializable, OwnableUpgradeable {

    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    uint256 public refFeePercent;
    bool public initialized;

    event Trade(address indexed trader, address indexed subject, bool indexed isBuy, uint256 shareAmount, uint256 ethAmount, uint256 protocolEthAmount, uint256 subjectEthAmount, uint256 supply);

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
        __Ownable_init(_feeDestination);
        refs[_feeDestination].active = true;
        setFeeDestination(_feeDestination);
        setProtocolFeePercent(45000000000000000); // 0.045
        setSubjectFeePercent(45000000000000000); // 0.045
        setRefFeePercent(10000000000000000); // 0.01
        initialized = true;
    }

    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        subjectFeePercent = _feePercent;
    }

    function setRefFeePercent(uint256 _feePercent) public onlyOwner {
        refFeePercent = _feePercent;
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
    }

    function buyShares(address sharesSubject, uint256 amount) public payable {
        require(initialized == true, 'NOT_INITIALIZED_YET');
        require(amount > 0, 'ZERO_AMOUNT');
        require(refs[msg.sender].active == true, "Signup first");
        address ref = refs[msg.sender].referrer;
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > 0 || sharesSubject == msg.sender, "Only the shares' subject can buy the first share");
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 refFee = price * refFeePercent / 1 ether;
        require(msg.value >= price + protocolFee + subjectFee, "Insufficient payment");
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] + amount;
        sharesSupply[sharesSubject] = supply + amount;
        emit Trade(msg.sender, sharesSubject, true, amount, price, protocolFee, subjectFee, supply + amount);
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = sharesSubject.call{value: subjectFee}("");
        (bool success3, ) = ref.call{value: refFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
    }

    function sellShares(address sharesSubject, uint256 amount) public payable {
        require(initialized == true, 'NOT_INITIALIZED_YET');
        require(amount > 0, 'ZERO_AMOUNT');
        require(refs[msg.sender].active == true, "Signup first");
        address ref = refs[msg.sender].referrer;
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 refFee = price * refFeePercent / 1 ether;
        require(sharesBalance[sharesSubject][msg.sender] >= amount, "Insufficient shares");
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] - amount;
        sharesSupply[sharesSubject] = supply - amount;
        emit Trade(msg.sender, sharesSubject, false, amount, price, protocolFee, subjectFee, supply - amount);
        (bool success1, ) = msg.sender.call{value: price - protocolFee - subjectFee}("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = sharesSubject.call{value: subjectFee}("");
        (bool success4, ) = ref.call{value: refFee}("");
        require(success1 && success2 && success3 && success4, "Unable to send funds");
    }
}