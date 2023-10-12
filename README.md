# MoneyMates Smart Contract Documentation

## Overview

The `MoneyMates` smart contract enables users to buy and sell shares of a subject. The system also has a referral mechanism to encourage user acquisition. When shares are bought or sold, various fees are levied and distributed to different stakeholders.

## Dependencies

- `Initializable.sol`: Provides a way to initialize a smart contract.
- `Ownable2StepUpgradeable.sol`: Enables smart contract ownership, ensuring only the owner can call certain functions.

## Variables

1. `protocolFeeDestination`: The address where the protocol fee is sent.
2. `protocolFeePercent`: Percentage of the protocol fee.
3. `subjectFeePercent`: Percentage of the fee for the subject of shares.
4. `refFeePercent`: Percentage of the referral fee.
5. `shares_rate_limit`: Rate limit to control the number of transactions per block for a specific shares subject.
6. `initialized`: A boolean to check if the contract has been initialized.
7. `UserInfo`: Struct that holds data for each user (referrer, number of people referred, and activation status).
8. Mappings for:
   - `rateLimit`: Tracks transaction count per block number for each shares subject.
   - `frontrunProtection`: Tracks the last block number a trader traded for a shares subject.
   - `sharesBalance`: Tracks the balance of shares for each holder and shares subject.
   - `sharesSupply`: Total supply of shares for a given subject.
   - `refs`: Holds the `UserInfo` struct for each user.

## Events

1. `Trade`: Triggered when a user trades shares. Captures trade details.
2. `Signup`: Captures details when a new user signs up.
3. `NewReferral`: Triggered when a user refers another user.
4. `ProtocolFeeUpdate`: Logs changes in the protocol fee percentage.
5. `SubjectFeeUpdate`: Logs changes in the subject fee percentage.
6. `ReferralFeeUpdate`: Logs changes in the referral fee percentage.
7. `FeeRecipientUpdate`: Logs changes in the protocol fee recipient.
8. `RateLimitUpdate`: Logs changes in the rate limit value.

## Functions

### Initialization and Setup:

1. `initialize(address _feeDestination)`: Initializes the contract with the fee destination and sets initial values for the contract's parameters.
2. `setFeeDestination(address _feeDestination)`: Sets the destination for the protocol fee.
3. `setProtocolFeePercent(uint256 _feePercent)`: Updates the protocol fee percentage.
4. `setSubjectFeePercent(uint256 _feePercent)`: Updates the subject fee percentage.
5. `setRefFeePercent(uint256 _feePercent)`: Updates the referral fee percentage.
6. `setRateLimitValue(uint256 _rateLimitValue)`: Sets the rate limit for transactions per block for each shares subject.

### Share Price Calculation:

7. `getPrice(uint256 supply, uint256 amount)`: Calculates the price based on supply and amount using a mathematical formula.
8. `getBuyPrice(address sharesSubject, uint256 amount)`: Calculates the price to buy a given amount of shares for a subject.
9. `getSellPrice(address sharesSubject, uint256 amount)`: Calculates the price to sell a given amount of shares for a subject.
10. `getBuyPriceAfterFee(address sharesSubject, uint256 amount)`: Calculates the buying price after accounting for all applicable fees.
11. `getSellPriceAfterFee(address sharesSubject, uint256 amount)`: Calculates the selling price after accounting for all applicable fees.

### Main Actions:

12. `signup(address referrer)`: A new user signs up using a referrer's address.
13. `buyShares(address sharesSubject, uint256 amount)`: Buys shares of a subject for a given amount. Ensures the right fees are levied and sent to the respective recipients.
14. `sellShares(address sharesSubject, uint256 amount)`: Sells shares of a subject for a given amount. Ensures the right fees are levied and deducted from the payout.

## Important Notes:

- Comments such as `FIX: HAL-XX` likely refer to some security or bug fixes, which are integrated into the contract functions.
- This smart contract has multiple security measures in place, such as rate limiting and front-running protection.
- Only the owner can update certain parameters like fee percentages and rate limits.
- The contract ensures no fees exceed a predefined maximum to prevent excessive charges.
- The contract requires users to sign up before they can buy or sell shares, and this is enforced in the trading functions.

## Closing Thoughts

This documentation provides a high-level overview of the `MoneyMates` smart contract. Developers should refer to the contract code and inline comments for a deeper understanding and when implementing further functionalities or changes.
