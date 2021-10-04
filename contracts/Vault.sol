// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

/**
   * ALERT: Known Security Hazard! (this is only for learning purposes)
   * In the entire contract we are relying on Uniswap and CurveFi. 
   * We should add bounds to this code to make this operations execute 
   * only if the values are within the bounds.
   * This kind of check would prevent attacks such as flashloan attacks,
   * which can create imbalances in the Uniswap/CurveFi pool that
   * ccould be used to exploit this contract.
*/

interface ICurve3Pool {
    function add_liquidity( uint256[3] memory amounts ,  uint256 in_mint_amount ) external;
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;

}

interface LiquidityGaugeV2 {
    function deposit(uint256 _value) external;
    function claim_rewards() external;

}

contract Vault is ERC20,ReentrancyGuard {

    event Deposit(
        address indexed sender,
        uint256 lpAmount,
        uint256 amount
    );

    event AddedLiquidity(
        address indexed sender,
        address indexed to,
        uint256 amount
    );

    event Withdraw(
        address indexed sender,
        uint256 lpAmount,
        uint256 amount
    );

     event Harvested(
        address indexed sender,
        uint256 CRVAmount,
        uint256 DAIAmount
    );

    IERC20 public immutable tokenDai;
    ICurve3Pool public immutable curve3Pool;
    IERC20 public immutable CRVaddress;
    ISwapRouter public immutable swapRouter;
    LiquidityGaugeV2 public immutable curveFi_LPGauge;

    // For this example,pool fee is set to 0.3%.
    uint24 public constant poolFee = 3000;


    /**
     * Deposits DAI tokens and mints LP tokens in proportion to the
     * vault's current holdings.
     * It is assumed that the user
     * has approved the use of DAI to this Vault.
     * Also, assumed that all deposited funds are
     * immediately deposited into the curve3Pool. In production it
     * would make more sense to have part of the pool being Idle
     * and part of the pool providing liquidity to the curve3Pool.
     *
     * Addresses could be hardcoded to the contract, depends on requirements.
     * @param _tokenDai Address of DAI contract. MainNet:  0x6B175474E89094C44Da98b954EedeAC495271d0F
     * @param _CRVaddress Address of CRV contract. MainNet: 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490
     * @param _curve3Pool Address of curve3Pool contract. MainNet: 0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7
     * @param _uniRouter Address of UniRouter contract. MainNet: 0xE592427A0AEce92De3Edee1F18E0157C05861564
     * @param _curveFi_LPGauge Address of curveFi LPGauge contract. MainNet: 0xFD4D8a17df4C27c1dD245d153ccf4499e806C87D
   */
   
    constructor(
        address _tokenDai,
        address _CRVaddress,
        address _curve3Pool,
        address _uniRouter,
        address _curveFi_LPGauge

    ) ERC20("LPToken", "LP") {
        require (_tokenDai != address(0) && _CRVaddress != address(0)
        && _curve3Pool != address(0) && _uniRouter != address(0), "Not valid address");
        tokenDai = IERC20(_tokenDai);
        curve3Pool = ICurve3Pool(_curve3Pool);
        CRVaddress = IERC20(_CRVaddress);
        swapRouter = ISwapRouter(_uniRouter);
        curveFi_LPGauge = LiquidityGaugeV2 (_curveFi_LPGauge);
    }

    /**
     * Deposits DAI tokens and mints LP tokens in proportion to the
     * vault's current holdings.
     * It is assumed that the user
     * has approved the use of DAI to this Vault.
     * All deposited funds are
     * immediately deposited into the curve3Pool. In production it
     * would make more sense to have part of the pool being Idle
     * and part of the pool providing liquidity to the curve3Pool.
     * @param _amount Number of DAI token deposited
     * @return lpAmount Number of LP tokens minted
   */
   function deposit(
        uint256 _amount
    )
        external
        nonReentrant
        returns (
            uint256 lpAmount
        )
    {
        require(_amount > 0, "Amount equal to zero");

        // Pull in tokens from sender
        bool success = tokenDai.transferFrom(msg.sender, address(this), _amount);
        require (success, "Failed to transfer tokens");


        uint256 _currentSupply = totalSupply();

        // Calculate lpAmount to mint
        // If first deposit, mintedAmount == depositedAmount
        if (_currentSupply == 0) {
            lpAmount = _amount;
        } else {
            lpAmount = _calculateLpAmount(_amount);
        }

        // Mint lPAmount to sender
        _mint(msg.sender, lpAmount);

        emit Deposit(msg.sender, lpAmount, _amount);

        _addLiquidity(_amount);

    }

    /**
     * @dev Adds amount of DAI coins to the Curve3Pool
    */
    function _addLiquidity(uint256 _amount) internal {
        tokenDai.approve(address(curve3Pool), _amount);
        uint256[3] memory _amounts = [_amount, 0, 0];

        emit AddedLiquidity(msg.sender, address(curve3Pool),_amount);

        //Add liquidity -> transfer of tokens
        curve3Pool.add_liquidity(_amounts,0);

    }

    /**
     * @dev Calculate the amount of LP tokens that need to be
     * minted in proportion to the vault's current holdings.
    */
    function _calculateLpAmount(uint256 amount)
        internal
        view
        returns (
            uint256 lpAmount
        )
    {
        uint256 _currentSupply = totalSupply();

        uint256 _totalAmount = _getTotalAmountVault();

        // If total supply > 0, vault can't be empty => _totalAmount > 0
        assert(_currentSupply == 0 || _totalAmount > 0 );

        // Not using safeMath because it is not needed after Solidity 8.0
        lpAmount = (amount * _currentSupply) / _totalAmount;

    }


    /**
     * Stake all the CRV tokens available
   */
    function stakeCRV() external {
      //Step 2 - stake Curve LP tokens into Gauge and get CRV rewards
      uint256 curveLPBalance = IERC20(CRVaddress).balanceOf(address(this));

      CRVaddress.approve(address(curveFi_LPGauge), curveLPBalance);
      curveFi_LPGauge.deposit(curveLPBalance);
    }

    /**
     * @dev Calculate the vault's total current holdings.
     * First calculates the total holdings available if all the liquidity were
     * to be withdrawn from the Curve3Pool pool
     * Then adding the amount of tokens currenctly held by this contract
     * obtained by harvesting/others.
    */
    function _getTotalAmountVault() internal view returns (uint256 _totalAmount) {
        uint256 value =  totalSupply();
        _totalAmount = curve3Pool.calc_withdraw_one_coin(value,0);

        _totalAmount += tokenDai.balanceOf(address(this));
    }


    /**
     * Withdraw underlying tokens
     * All deposited
     * amounts are provided as liquidity for the Curve3 Pool, it
     * is required to withdraw liquidity from that pool.
     * In production it would be more normal to have part of the
     * tokens Idle to avoid having to remove liquidity in every
     * withdrawal.
     * After withdrawing the liquidity, burning the corresponding
     * amount of LP tokens and transfering the underlying tokens
     * to the sender
     *
     * @param _lpAmount Number of LP token approved for withdrawal
   */
    function withdraw(uint256 _lpAmount ) external nonReentrant{

        require (_lpAmount > 0 , "Amount too low");
        uint256 balance = balanceOf(msg.sender);
        require (_lpAmount >= balance, "Amount trying to withdraw is too high");


        uint256 _amountToWithdraw = _calculateAmountToWithdraw(_lpAmount);

        _withdrawFromLiqPool(_amountToWithdraw);

        // Burn the amount of LP tokens
        _burn(msg.sender, _lpAmount);

        emit Withdraw (msg.sender, _lpAmount, _amountToWithdraw);

        tokenDai.transfer(msg.sender, _amountToWithdraw);

    }


    /**
     * @dev Provided an amount of LP tokens, withdraw the corresponding
     * amount of liquidity from the curve3Pool.
     * Transfer those tokens to the sender
    */
    function _withdrawFromLiqPool (uint256 _amountToWithdraw) internal {

        uint256 _initialBalance = tokenDai.balanceOf (address(this));

        //Withdraw coin 0 (DAI) and minimum amount 0
        curve3Pool.remove_liquidity_one_coin(_amountToWithdraw, 0, 0);

        //Calculation to get the amount of DAI withdrawn
        uint256 _finalBalance = tokenDai.balanceOf (address(this));
        uint256 _withdrawnAmount = _finalBalance - _initialBalance;
        require (_withdrawnAmount > 0);

    }

    /**
     * @dev Calculate amount to withdraw from the pool based on
     * the amount of LP tokens provided
    */
    function _calculateAmountToWithdraw(uint256 _lpAmount)
        internal
        view
        returns (
            uint256 _amountToWithdraw
        )
    {
        uint256 _currentSupply = totalSupply();
        uint256 _totalAmount = _getTotalAmountVault();
        _amountToWithdraw = (_lpAmount * _totalAmount) / _currentSupply;
    }


    /**
     * Calculate exchange rate for the underlying token (DAI) and the LP token
     * Applied factor of 10^(precision) to get decimal precision
     * Hardcoded precision but it could be an input to the function
     * On the client/frontend we have to undo it to get the actual number
     * @return _exchangeRate Exchange rate DAI-LP token * 10^18

   */
    function exchangeRate() external view returns (uint256 _exchangeRate) {
        uint256 _currentSupply = totalSupply();
        uint256 _totalAmount = _getTotalAmountVault();

        uint8 _precision = 18;

        _exchangeRate = (_totalAmount * uint(10) ** (_precision)) / _currentSupply;
    }

   /**
     * Harvest all the CRV tokens obtained as a reward for providing
     * liquidity to the curve3Pool. Then using Uniswap to swap them for
     * underslying tokens (DAI).
     * Amount of DAI obtained is locked in this address.
    * It would make senseto add a rebalance function
     * or a way to distribute harvested tokens to LP token holders.
     * @return amountDaiHarvested Amount of DAI obtained from harvesting.
   */
    function harvest() external nonReentrant returns (uint256 amountDaiHarvested){

        curveFi_LPGauge.claim_rewards();

        uint256 _balanceCRV = CRVaddress.balanceOf(address(this));

        amountDaiHarvested = _swap(_balanceCRV);

        emit Harvested (msg.sender, _balanceCRV, amountDaiHarvested);

    }

    /**
     * @dev Convert CRV to DAI through Uniswap
     * Coins will be owned by this contract address
    */
    function _swap(uint256 _amount) internal returns (uint256 amountOut) {

        // Approve the router to spend CRV.
        TransferHelper.safeApprove(address(tokenDai), address(swapRouter), _amount);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(CRVaddress),
                tokenOut: address(tokenDai),
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }

    /**
     * @dev TO BE DONE:
     * Rebalance or redistribute function to be able to use the harvested
     * coins.
    */
    

}
