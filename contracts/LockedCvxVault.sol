// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "hardhat/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626VaultInitializable} from "./ERC4626VaultInitializable.sol";
import {ICvxLocker} from "./interfaces/ICvxLocker.sol";
import {IVotiumMultiMerkleStash} from "./interfaces/IVotiumMultiMerkleStash.sol";

contract LockedCvxVault is ERC4626VaultInitializable {
    using SafeERC20 for ERC20;

    address public vaultController;
    uint256 public depositDeadline;
    uint256 public lockExpiry;
    ICvxLocker public cvxLocker;
    IVotiumMultiMerkleStash public votiumMultiMerkleStash;

    event UnlockCvx(uint256 amount);
    event LockCvx(uint256 amount);
    event Inititalized(
        uint256 _depositDeadline,
        uint256 _lockExpiry,
        ICvxLocker _cvxLocker,
        ERC20 _underlying,
        string _name,
        string _symbol
    );
    event ClaimedVotiumReward(
        address indexed voteCvxVault,
        address indexed token,
        uint256 index,
        uint256 amount,
        bytes32[] merkleProof
    );

    error ZeroAddress();
    error ZeroAmount();
    error BeforeDepositDeadline(uint256 timestamp);
    error AfterDepositDeadline(uint256 timestamp);
    error BeforeLockExpiry(uint256 timestamp);
    error NotVaultController();

    /**
        @notice Initializes the contract
        @param  _vaultController  address     VaultController
        @param  _depositDeadline  uint256     Deposit deadline
        @param  _lockExpiry       uint256     Lock expiry for CVX (17 weeks after deposit deadline)
        @param  _cvxLocker        ICvxLocker  Deposit deadline
        @param  _underlying       ERC20       Underlying asset
        @param  _name             string      Token name
        @param  _symbol           string      Token symbol
     */
    function initialize(
        address _vaultController,
        uint256 _depositDeadline,
        uint256 _lockExpiry,
        address _cvxLocker,
        address _votiumMultiMerkleStash,
        ERC20 _underlying,
        string memory _name,
        string memory _symbol
    ) external {
        if (_vaultController == address(0)) revert ZeroAddress();
        vaultController = _vaultController;

        if (_depositDeadline == 0) revert ZeroAmount();
        depositDeadline = _depositDeadline;

        if (_lockExpiry == 0) revert ZeroAmount();
        lockExpiry = _lockExpiry;

        if (_cvxLocker == address(0)) revert ZeroAddress();
        cvxLocker = ICvxLocker(_cvxLocker);

        if (_votiumMultiMerkleStash == address(0)) revert ZeroAddress();
        votiumMultiMerkleStash = IVotiumMultiMerkleStash(
            _votiumMultiMerkleStash
        );

        _initialize(_underlying, _name, _symbol);
    }

    modifier onlyVaultController() {
        if (msg.sender != vaultController) revert NotVaultController();
        _;
    }

    /**
        @notice Unlocks CVX
     */
    function unlockCvx() external {
        (, uint256 unlockable, , ) = cvxLocker.lockedBalances(address(this));
        if (unlockable != 0)
            cvxLocker.processExpiredLocks(false, 0, address(this));
        emit UnlockCvx(unlockable);
    }

    /**
        @notice Check underlying amount and timestamp
        @param  underlyingAmount  uint256  CVX amount
     */
    function beforeDeposit(uint256 underlyingAmount) internal view override {
        if (underlyingAmount == 0) revert ZeroAmount();
        if (depositDeadline < block.timestamp)
            revert AfterDepositDeadline(block.timestamp);
    }

    /**
        @notice Check underlying amount and timestamp
        @param  underlyingAmount  uint256  CVX amount
     */
    function beforeWithdraw(uint256 underlyingAmount) internal override {
        if (underlyingAmount == 0) revert ZeroAmount();
        if (lockExpiry > block.timestamp)
            revert BeforeLockExpiry(block.timestamp);
    }

    /**
        @notice Lock CVX
        @param  underlyingAmount  uint256  CVX amount
     */
    function afterDeposit(uint256 underlyingAmount) internal override {
        underlying.safeIncreaseAllowance(address(cvxLocker), underlyingAmount);
        cvxLocker.lock(address(this), underlyingAmount, 0);
        emit LockCvx(underlyingAmount);
    }

    /**
        @notice Get total balance: locked CVX balance + CVX balance
     */
    function totalHoldings() public view override returns (uint256) {
        (uint256 total, , , ) = cvxLocker.lockedBalances(address(this));

        return total + underlying.balanceOf(address(this));
    }

    /**
        @notice Claim Votium reward
        @notice Restricted to VaultController to ensure reward added on VoteCvxVault
        @param  voteCvxVault  address    VoteCVXVault address
        @param  token         address    Reward token address
        @param  index         uint256    Merkle tree node index
        @param  amount        uint256    Reward token amount
        @param  merkleProof   bytes32[]  Merkle proof
     */
    function claimVotiumReward(
        address voteCvxVault,
        address token,
        uint256 index,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external onlyVaultController {
        // Claims must be after deposit deadline
        if (depositDeadline > block.timestamp)
            revert BeforeDepositDeadline(block.timestamp);

        if (voteCvxVault == address(0)) revert ZeroAddress();

        ERC20 t = ERC20(token);

        // Handles tokens with fees and when CVX is a reward (don't want to transfer unlocked balance)
        uint256 balanceBeforeClaim = t.balanceOf(address(this));

        // Validates token, index, amount, and merkleProof
        votiumMultiMerkleStash.claim(
            token,
            index,
            address(this),
            amount,
            merkleProof
        );

        // Transfer rewards to VoteCvxVault, which can be claimed by vault shareholders
        t.safeTransfer(
            voteCvxVault,
            t.balanceOf(address(this)) - balanceBeforeClaim
        );

        emit ClaimedVotiumReward(
            voteCvxVault,
            token,
            index,
            amount,
            merkleProof
        );
    }
}