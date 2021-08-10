// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { MapleTest, Hevm } from "../../modules/maple-test/contracts/test.sol";

import { MapleToken } from "../MapleToken.sol";

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

contract MapleTokenTest is MapleTest {

    MapleToken token;
    MapleTokenUser usr;

    uint256 skOwner   = 1;
    uint256 skSpender = 2;
    uint256 nonce     = 0;
    uint256 deadline  = 5000000000; // Timestamp far in the future

    address owner   = hevm.addr(skOwner);
    address spender = hevm.addr(skSpender);

    function setUp() public {
        hevm.warp(deadline - 52 weeks);
        token = new MapleToken("Maple Token", "MPL", address(0x1111111111111111111111111111111111111111));
        usr   = new MapleTokenUser(token);
    }

    function test_token_address() public {
        assertEq(address(token), address(0xCe71065D4017F316EC606Fe4422e11eB2c47c246));
    }

    function test_initial_balance() public {
        assertEq(token.balanceOf(address(this)), 10_000_000 * WAD);
    }

    function test_typehash() public {
        assertEq(token.PERMIT_TYPEHASH(), keccak256("Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)"));
    }

    function test_domain_separator() public {
        assertEq(token.DOMAIN_SEPARATOR(), 0x06c0ee43424d25534e5af6b6af862333b542f6583ff9948b8299442926099eec);
    }

    function test_permit() public {
        uint256 amount = 10 * WAD;
        assertEq(token.nonces(owner),             0);
        assertEq(token.allowance(owner, spender), 0);

        (uint8 v, bytes32 r, bytes32 s) = getValidPermitSignature(amount, owner, skOwner, deadline);
        assertTrue(usr.try_permit(owner, spender, amount, deadline, v, r, s));

        assertEq(token.allowance(owner, spender), amount);
        assertEq(token.nonces(owner),             1);
    }

    function test_permit_zero_address() public {
        uint256 amount = 10 * WAD;
        (uint8 v, bytes32 r, bytes32 s) = getValidPermitSignature(amount, owner, skOwner, deadline);
        assertTrue(!usr.try_permit(address(0), spender, amount, deadline, v, r, s));
    }

    function test_permit_non_owner_address() public {
        uint256 amount = 10 * WAD;
        (uint8 v, bytes32 r, bytes32 s) = getValidPermitSignature(amount, owner, skOwner, deadline);
        assertTrue(!usr.try_permit(spender, owner, amount, deadline, v,  r,  s));

        (v, r, s)= getValidPermitSignature(amount, spender, skSpender, deadline);
        assertTrue(!usr.try_permit(owner, spender, amount, deadline, v, r, s));
    }

    function test_permit_with_expiry() public {
        uint256 amount = 10 * WAD;
        uint256 expiry = 482112000 + 1 hours;

        // Expired permit should fail
        hevm.warp(482112000 + 1 hours + 1);
        assertEq(block.timestamp, 482112000 + 1 hours + 1);

        (uint8 v, bytes32 r, bytes32 s) = getValidPermitSignature(amount, owner, skOwner, expiry);
        assertTrue(!usr.try_permit(owner, spender, amount, expiry, v, r, s));

        assertEq(token.allowance(owner, spender), 0);
        assertEq(token.nonces(owner),             0);

        // Valid permit should succeed
        hevm.warp(482112000 + 1 hours);
        assertEq(block.timestamp, 482112000 + 1 hours);

        (v, r, s) = getValidPermitSignature(amount, owner, skOwner, expiry);
        assertTrue(usr.try_permit(owner, spender, amount, expiry, v, r, s));

        assertEq(token.allowance(owner, spender), amount);
        assertEq(token.nonces(owner),             1);
    }

    function test_permit_replay() public {
        uint256 amount = 10 * WAD;
        
        (uint8 v, bytes32 r, bytes32 s) = getValidPermitSignature(amount, owner, skOwner, deadline);

        // First time should succeed
        assertTrue(usr.try_permit(owner, spender, amount, deadline, v, r, s));

        // Second time nonce has been consumed and should fail
        assertTrue(!usr.try_permit(owner, spender, amount, deadline, v, r, s));
    }

    // Returns an ERC-2612 `permit` digest for the `owner` to sign
    function getDigest(address owner_, address spender_, uint256 value_, uint256 nonce_, uint256 deadline_) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                '\x19\x01',
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(token.PERMIT_TYPEHASH(), owner_, spender_, value_, nonce_, deadline_))
            )
        );
    }

    // Returns a valid `permit` signature signed by this contract's `owner` address
    function getValidPermitSignature(uint256 value, address owner_, uint256 ownerpk, uint256 deadline_) public view returns (uint8, bytes32, bytes32) {
        bytes32 digest = getDigest(owner_, spender, value, nonce, deadline_);
        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(ownerpk, digest);
        return (v, r, s);
    }

}
