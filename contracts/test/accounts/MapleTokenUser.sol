// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

contract MapleTokenUser {

    function try_permit(address mplToken, address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external returns (bool ok) {
        string memory sig = "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)";
        (ok,) = mplToken.call(abi.encodeWithSignature(sig, owner, spender, value, deadline, v, r, s));
    }

}
