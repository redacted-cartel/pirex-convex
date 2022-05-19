// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "forge-std/Test.sol";
import {PirexCvx} from "contracts/PirexCvx.sol";
import {PirexCvxConvex} from "contracts/PirexCvxConvex.sol";
import {PxCvx} from "contracts/PxCvx.sol";
import {HelperContract} from "./HelperContract.sol";

contract PirexCvxBaseTest is Test, HelperContract {
    event SetContract(PirexCvx.Contract indexed c, address contractAddress);

    /**
        @notice Set the new contract
        @param  c            PirexCvx.Contract  Contract enum
        @param  newContract  address            New contract address
     */
    function _setContract(PirexCvx.Contract c, address newContract) internal {
        vm.expectEmit(true, false, false, true);

        emit SetContract(c, newContract);

        // Set the new contract address
        pirexCvx.setContract(c, newContract);
    }

    /*//////////////////////////////////////////////////////////////
                        setContract TESTS
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Test tx reversion if caller is not authorized
     */
    function testCannotSetContractNotAuthorized() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(secondaryAccounts[0]);

        pirexCvx.setContract(PirexCvx.Contract.UnionPirexVault, address(this));
    }

    /**
        @notice Test tx reversion if the specified address is the zero address
     */
    function testCannotSetContractZeroAddress() external {
        vm.expectRevert(PirexCvxConvex.ZeroAddress.selector);

        pirexCvx.setContract(PirexCvx.Contract.UnionPirexVault, address(0));
    }

    /**
        @notice Test setting PxCvx
     */
    function testSetContractPxCvx() external {
        address oldContract = address(pirexCvx.pxCvx());
        address newContract = address(this);

        _setContract(PirexCvx.Contract.PxCvx, newContract);

        address updatedContract = address(pirexCvx.pxCvx());

        assertFalse(oldContract == newContract);
        assertEq(updatedContract, newContract);
    }

    /**
        @notice Test setting PirexFees
     */
    function testSetContractPirexFees() external {
        address oldContract = address(pirexCvx.pirexFees());
        address newContract = address(this);

        _setContract(PirexCvx.Contract.PirexFees, newContract);

        address updatedContract = address(pirexCvx.pirexFees());

        assertFalse(oldContract == newContract);
        assertEq(updatedContract, newContract);
    }

    /**
        @notice Test setting UpCvx
     */
    function testSetContractUpCvx() external {
        address oldContract = address(pirexCvx.upCvx());
        address newContract = address(this);

        _setContract(PirexCvx.Contract.UpCvx, newContract);

        address updatedContract = address(pirexCvx.upCvx());

        assertFalse(oldContract == newContract);
        assertEq(updatedContract, newContract);
    }

    /**
        @notice Test setting SpCvx
     */
    function testSetContractSpCvx() external {
        address oldContract = address(pirexCvx.spCvx());
        address newContract = address(this);

        _setContract(PirexCvx.Contract.SpCvx, newContract);

        address updatedContract = address(pirexCvx.spCvx());

        assertFalse(oldContract == newContract);
        assertEq(updatedContract, newContract);
    }

    /**
        @notice Test setting RpCvx
     */
    function testSetContractRpCvx() external {
        address oldContract = address(pirexCvx.rpCvx());
        address newContract = address(this);

        _setContract(PirexCvx.Contract.RpCvx, newContract);

        address updatedContract = address(pirexCvx.rpCvx());

        assertFalse(oldContract == newContract);
        assertEq(updatedContract, newContract);
    }

    /**
        @notice Test setting VpCvx
     */
    function testSetContractVpCvx() external {
        address oldContract = address(pirexCvx.vpCvx());
        address newContract = address(this);

        _setContract(PirexCvx.Contract.VpCvx, newContract);

        address updatedContract = address(pirexCvx.vpCvx());

        assertFalse(oldContract == newContract);
        assertEq(updatedContract, newContract);
    }

    /**
        @notice Test setting UnionPirexVault
     */
    function testSetContractUnionPirexVault() external {
        address oldContract = address(pirexCvx.unionPirex());
        address newContract = address(this);

        _setContract(PirexCvx.Contract.UnionPirexVault, newContract);

        address updatedContract = address(pirexCvx.unionPirex());

        assertFalse(oldContract == newContract);
        assertEq(updatedContract, newContract);

        // Check the allowances
        assertEq(pxCvx.allowance(address(pirexCvx), oldContract), 0);
        assertEq(
            pxCvx.allowance(address(pirexCvx), newContract),
            type(uint256).max
        );
    }

    /*//////////////////////////////////////////////////////////////
                        getCurrentEpoch TESTS
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Test getting current epoch
     */
    function testGetCurrentEpoch() external {
        uint256 expectedEpoch = (block.timestamp / EPOCH_DURATION) *
            EPOCH_DURATION;

        assertEq(pirexCvx.getCurrentEpoch(), expectedEpoch);
    }
}
