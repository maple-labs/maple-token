// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { SafeMath }          from "../modules/openzeppelin-contracts/contracts/math/SafeMath.sol";
import { SignedSafeMath }    from "../modules/openzeppelin-contracts/contracts/math/SignedSafeMath.sol";
import { ERC20 }             from "../modules/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20, SafeERC20 } from "../modules/openzeppelin-contracts/contracts/token/ERC20/SafeERC20.sol";

import { IntSafeMath }  from "./libraries/IntSafeMath.sol";
import { UintSafeMath } from "./libraries/UintSafeMath.sol";

import { IERC2222 } from "./interfaces/IERC2222.sol";

abstract contract ERC2222 is IERC2222, ERC20 {

    using SafeERC20      for  IERC20;
    using SafeMath       for uint256;
    using SignedSafeMath for  int256;
    using IntSafeMath    for  int256;
    using UintSafeMath   for uint256;

    address public override fundsToken;
    uint256 public override fundsTokenBalance;

    uint256 internal constant pointsMultiplier = 2 ** 128;
    uint256 internal          pointsPerShare;

    mapping(address => int256)  internal pointsCorrection;
    mapping(address => uint256) internal withdrawnFunds;

    constructor(string memory name, string memory symbol, address _fundsToken) ERC20(name, symbol) public {
        fundsToken = _fundsToken;
    }

    /**
     * prev. distributeDividends
     * @dev Distributes funds to token holders.
     * @dev It reverts if the total supply of tokens is 0.
     * It emits the `FundsDistributed` event if the amount of received ether is greater than 0.
     * About undistributed funds:
     *   In each distribution, there is a small amount of funds which does not get distributed,
     *     which is `(msg.value * pointsMultiplier) % totalSupply()`.
     *   With a well-chosen `pointsMultiplier`, the amount funds that are not getting distributed
     *     in a distribution can be less than 1 (base unit).
     *   We can actually keep track of the undistributed ether in a distribution
     *     and try to distribute it in the next distribution ....... todo implement
     */
    function _distributeFunds(uint256 value) internal {
        require(totalSupply() > 0, "FDT:SUPPLY_EQ_ZERO");

        if (value > 0) {
            pointsPerShare = pointsPerShare.add(value.mul(pointsMultiplier) / totalSupply());
            emit FundsDistributed(msg.sender, value);
            emit PointsPerShareUpdated(pointsPerShare);
        }
    }

    /**
     * @dev Prepares funds withdrawal
     * @dev It emits a `FundsWithdrawn` event if the amount of withdrawn ether is greater than 0.
     */
    function _prepareWithdraw() internal returns (uint256) {
        uint256 _withdrawableDividend = withdrawableFundsOf(msg.sender);

        withdrawnFunds[msg.sender] = withdrawnFunds[msg.sender].add(_withdrawableDividend);

        emit FundsWithdrawn(msg.sender, _withdrawableDividend, withdrawnFunds[msg.sender]);

        return _withdrawableDividend;
    }

    /**
     * @dev Prepares funds withdrawal on behalf of a user
     * @dev It emits a `FundsWithdrawn` event if the amount of withdrawn ether is greater than 0.
     */
    function _prepareWithdrawOnBehalf(address user) internal returns (uint256) {
        uint256 _withdrawableDividend = withdrawableFundsOf(user);

        withdrawnFunds[user] = withdrawnFunds[user].add(_withdrawableDividend);

        emit FundsWithdrawn(user, _withdrawableDividend, withdrawnFunds[user]);

        return _withdrawableDividend;
    }

    function withdrawableFundsOf(address _owner) public view override returns (uint256) {
        return accumulativeFundsOf(_owner).sub(withdrawnFunds[_owner]);
    }

    function withdrawnFundsOf(address _owner) public view override returns (uint256) {
        return withdrawnFunds[_owner];
    }

    function accumulativeFundsOf(address _owner) public view override returns (uint256) {
        return
            pointsPerShare
                .mul(balanceOf(_owner))
                .toInt256Safe()
                .add(pointsCorrection[_owner])
                .toUint256Safe() / pointsMultiplier;
    }

    /**
     * @dev   Internal function that transfer tokens from one address to another.
     * @dev   Update pointsCorrection to keep funds unchanged.
     * @param from  The address to transfer from.
     * @param to    The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        require(to != address(this), "ERC20: transferring to token contract");
        super._transfer(from, to, value);

        int256 _magCorrection = pointsPerShare.mul(value).toInt256Safe();
        pointsCorrection[from] = pointsCorrection[from].add(_magCorrection);
        pointsCorrection[to] = pointsCorrection[to].sub(_magCorrection);

        emit PointsCorrectionUpdated(from, pointsCorrection[from]);
        emit PointsCorrectionUpdated(to,   pointsCorrection[to]);
    }

    /**
     * @dev   Internal function that mints tokens to an account.
     * @dev   Update pointsCorrection to keep funds unchanged.
     * @param account The account that will receive the created tokens.
     * @param value   The amount that will be created.
     */
    function _mint(address account, uint256 value) internal virtual override {
        super._mint(account, value);

        pointsCorrection[account] = pointsCorrection[account].sub(
            (pointsPerShare.mul(value)).toInt256Safe()
        );
        
        emit PointsCorrectionUpdated(account, pointsCorrection[account]);
    }

    /**
     * @dev   Internal function that burns an amount of the token of a given account.
     * @dev   Update pointsCorrection to keep funds unchanged.
     * @param account The account whose tokens will be burnt.
     * @param value   The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal virtual override {
        super._burn(account, value);

        pointsCorrection[account] = pointsCorrection[account].add(
            (pointsPerShare.mul(value)).toInt256Safe()
        );
        emit PointsCorrectionUpdated(account, pointsCorrection[account]);
    }

    function withdrawFunds() public virtual override {
        uint256 withdrawableFunds = _prepareWithdraw();

        if (withdrawableFunds > uint256(0)) {
            IERC20(fundsToken).safeTransfer(msg.sender, withdrawableFunds);

            _updateFundsTokenBalance();
        }
    }

    function withdrawFundsOnBehalf(address user) public virtual override {
        uint256 withdrawableFunds = _prepareWithdrawOnBehalf(user);

        if (withdrawableFunds > uint256(0)) {
            IERC20(fundsToken).safeTransfer(user, withdrawableFunds);

            _updateFundsTokenBalance();
        }
    }

    /**
     * @dev    Updates the current funds token balance and returns the difference of new and previous funds token balances
     * @return A int256 representing the difference of the new and previous funds token balance
     */
    function _updateFundsTokenBalance() internal virtual returns (int256) {
        uint256 _prevFundsTokenBalance = fundsTokenBalance;

        fundsTokenBalance = IERC20(fundsToken).balanceOf(address(this));

        return int256(fundsTokenBalance).sub(int256(_prevFundsTokenBalance));
    }

    function updateFundsReceived() public virtual override {
        int256 newFunds = _updateFundsTokenBalance();

        if (newFunds > 0) {
            _distributeFunds(newFunds.toUint256Safe());
        }
    }

}
