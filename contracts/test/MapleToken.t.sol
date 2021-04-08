// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import "ds-test/test.sol";

import "../MapleToken.sol";

interface Hevm {
    function warp(uint256) external;
}

contract MapleTokenUser {
    MapleToken token;

    constructor(MapleToken token_) public {
        token = token_;
    }

    function try_permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external returns (bool ok) {
        string memory sig = "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, owner, spender, value, deadline, v, r, s));
    }
}

contract MapleTokenTest is DSTest {

    Hevm hevm;
    MapleToken token;
    MapleTokenUser usr;

    uint256 constant WAD = 10 ** 18;

    address ali = 0x17ec8597ff92C3F44523bDc65BF0f1bE632917ff;
    address bob = 0x63FC2aD3d021a4D7e64323529a55a9442C444dA0;
    uint8     v = 28;
    bytes32   r = 0x1f51dadbe0df96581bacef94eadbe3053c79f784ab1737f5c6b33782b38cc723;
    bytes32   s = 0x21f4cf40918bdee22ada50c05c7718855daa41c88aa24d8645c3f9d1ffd1d7bb;
    uint8    v2 = 27;
    bytes32  r2 = 0x5e56d6b03030ad9a3f8b50cc70f1ee488ec69b6939334baac6148837a7cc9b96;
    bytes32  s2 = 0x4573435167adc2a7332a7aed96fce122e1baeda98518f1903832954ac68c6253;

    function setUp() public {
        hevm = Hevm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        hevm.warp(482112000);
        token = new MapleToken("Maple Token", "MPL", address(0x1111111111111111111111111111111111111111));
        usr = new MapleTokenUser(token);
        log_named_address("usr", address(usr));
    }

    function test_token_address() public {
        assertEq(address(token), address(0xDB356e865AAaFa1e37764121EA9e801Af13eEb83));
    }

    function test_initial_balance() public {
        assertEq(token.balanceOf(address(this)), 10_000_000 * WAD);
    }

    function test_typehash() public {
        assertEq(token.PERMIT_TYPEHASH(), 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9);
    }

    function test_domain_separator() public {
        assertEq(token.DOMAIN_SEPARATOR(), 0xd85593d420e1e73e8af750482b5cfee5ea0cba135ca2b28cc47519ec578bb8b9);
    }

    function test_permit() public {
        uint256 amount = 10 * WAD;
        assertEq(token.nonces(ali), 0);
        assertEq(token.allowance(ali, bob), 0);
        assertTrue(usr.try_permit(ali, bob, amount, uint(-1), v, r, s));
        assertEq(token.allowance(ali, bob), amount);
        assertEq(token.nonces(ali), 1);
    }

    function test_permit_zero_address() public {
        v = 0;
        uint256 amount = 10 * WAD;
        assertTrue(!usr.try_permit(address(0), bob, amount, uint(-1), v, r, s));
    }

    function test_permit_with_expiry() public {
        uint256 amount = 10 * WAD;
        uint256 expiry = 482112000 + 1 hours;

        // Expired permit should fail
        hevm.warp(482112000 + 2 hours);
        assertEq(now, 482112000 + 2 hours);
        assertTrue(!usr.try_permit(ali, bob, amount, expiry, v2, r2, s2));
        assertEq(token.allowance(ali, bob), 0);
        assertEq(token.nonces(ali), 0);

        // Valid permit should succeed
        hevm.warp(482112000 + 1 hours);
        assertEq(now, 482112000 + 1 hours);
        assertTrue(usr.try_permit(ali, bob, amount, expiry, v2, r2, s2));
        assertEq(token.allowance(ali, bob), amount);
        assertEq(token.nonces(ali), 1);
    }

    function test_permit_replay() public {
        uint256 amount = 10 * WAD;

        // First time should succeed
        assertTrue(usr.try_permit(ali, bob, amount, uint(-1), v, r, s));

        // Second time nonce has been consumed and should fail
        assertTrue(!usr.try_permit(ali, bob, amount, uint(-1), v, r, s));
    }
}
