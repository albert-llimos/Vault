# Vault

This is a simple Vault coded for learning purposes.

It implement a single-asset DAI vault that earns profit through depositing the funds into the Curve 3pool.
The vault is also an ERC20 token itself (for accounting purposes, to keep track of the funds of individual depositors). This type of ERC20 token shall be called LP token.
The vault implements the following functions:

- `deposit(uint256 underlyingAmount)` - allows a user to deposit `underlyingAmount` DAI and receive LP tokens in return
    - The user needs to have approved the vault to spend at least `underlyingAmount` DAI on his behalf
    - All the funds are then automatically provided as liquidity in the Curve pool.
- `withdraw(uint256 lpAmount)` - allows a user to withdraw `lpAmount` LP tokens and receive underlying tokens in return
- `harvest()` - claims the accumulated CRV rewards from Curve and converts them to DAI
- `exchangeRate()` - returns the exchange rate between the underlying token (DAI) and the LP token
- rebalance() - To be done


In order to compile, migrate/deploy or test, follow the standard procedure:

npm install

truffle compile

truffle migrate

truffle test

To run locally a ganache-cli should be running. Otherwise, add your mnemomic to the truffle-config and run in on a testnet (adding --network rinkeby)

The testing is far from completed due to a lack of time. However I have added a test environment and one example of test checking the events emmited.
