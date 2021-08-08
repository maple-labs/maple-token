// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { DSTest } from "../../modules/ds-test/contracts/test.sol";

import { MapleToken } from "../MapleToken.sol";

import { MapleTokenUser } from "./accounts/MapleTokenUser.sol";

interface Hevm {
    function warp(uint256) external;
}

contract MapleTokenTest is DSTest {

    Hevm           hevm;
    MapleToken     token;
    MapleTokenUser usr;

    uint256 constant WAD = 10 ** 18;

    address ali = 0x17ec8597ff92C3F44523bDc65BF0f1bE632917ff;
    address bob = 0x63FC2aD3d021a4D7e64323529a55a9442C444dA0;
    uint8     v = 27;
    bytes32   r = 0xd6ac3dffef695bb6035537394acd0294344798e77491a76b96a65fd4f7d32452;
    bytes32   s = 0x6252eda670c17df6d66ecb195124c7b7aee51c15842ea9f2704cc5ba0846ad0f;
    uint8    v2 = 28;
    bytes32  r2 = 0xd4b6b40d39494fb0ec5d688f1fb3520b683b81ddeca7c30f80d409bc1ef147b9;
    bytes32  s2 = 0x7c3da9183db3b075a7028b4bd96fc656cab4e67dd96cff6a74130f26c441dc9f;

    constructor() public {
        hevm = Hevm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
    }

    function setUp() public {
        hevm.warp(482112000);
        token = new MapleToken("Maple Token", "MPL", address(0x1111111111111111111111111111111111111111));
        usr   = new MapleTokenUser();
        log_named_address("usr", address(usr));
    }

    function test_token_address() public {
        assertEq(address(token), address(0xDB356e865AAaFa1e37764121EA9e801Af13eEb83));
    }

    function test_initial_balance() public {
        assertEq(token.balanceOf(address(this)), 10_000_000 * WAD);
    }

    function test_typehash() public {
        assertEq(token.PERMIT_TYPEHASH(), keccak256("Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)"));
    }

    function test_domain_separator() public {
        assertEq(token.DOMAIN_SEPARATOR(), 0xd85593d420e1e73e8af750482b5cfee5ea0cba135ca2b28cc47519ec578bb8b9);
    }

    function test_permit() public {
        uint256 amount = 10 * WAD;

        assertEq(token.nonces(ali),         0);
        assertEq(token.allowance(ali, bob), 0);

        assertTrue(usr.try_permit(address(token), ali, bob, amount, type(uint256).max, v, r, s));

        assertEq(token.allowance(ali, bob), amount);
        assertEq(token.nonces(ali),         1);
    }

    function test_permit_zero_address() public {
        assertTrue(!usr.try_permit(address(token), address(0), bob, 10 * WAD, type(uint256).max, 0, r, s));
    }

    function test_permit_non_owner_address() public {
        uint256 amount = 10 * WAD;
        assertTrue(!usr.try_permit(address(token), bob, ali, amount, type(uint256).max, v,  r,  s));
        assertTrue(!usr.try_permit(address(token), ali, bob, amount, type(uint256).max, v2, r2, s2));
    }

    function test_permit_with_expiry() public {
        uint256 amount = 10 * WAD;
        uint256 expiry = 482112000 + 1 hours;

        // Expired permit should fail
        hevm.warp(482112000 + 1 hours + 1);

        assertEq(block.timestamp, 482112000 + 1 hours + 1);

        assertTrue(!usr.try_permit(address(token), ali, bob, amount, expiry, v2, r2, s2));

        assertEq(token.allowance(ali, bob), 0);
        assertEq(token.nonces(ali),         0);

        // Valid permit should succeed
        hevm.warp(482112000 + 1 hours);

        assertEq(block.timestamp, 482112000 + 1 hours);

        assertTrue(usr.try_permit(address(token), ali, bob, amount, expiry, v2, r2, s2));

        assertEq(token.allowance(ali, bob), amount);
        assertEq(token.nonces(ali),         1);
    }

    function test_permit_replay() public {
        uint256 amount = 10 * WAD;

        // First time should succeed
        assertTrue(usr.try_permit(address(token), ali, bob, amount, uint(-1), v, r, s));

        // Second time nonce has been consumed and should fail
        assertTrue(!usr.try_permit(address(token), ali, bob, amount, uint(-1), v, r, s));
    }

}
