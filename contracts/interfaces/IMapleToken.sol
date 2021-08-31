// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { IERC2222 } from "./IERC2222.sol";

interface IMapleToken is IERC2222 {

    function DOMAIN_SEPARATOR() external pure returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address) external view returns (uint256);

    /**
        @dev   Approve by signature.
        @param owner    Owner address that signed the permit
        @param spender  Spender of the permit
        @param amount   Permit approval spend limit
        @param deadline Deadline after which the permit is invalid
        @param v        ECDSA signature v component
        @param r        ECDSA signature r component
        @param s        ECDSA signature s component
     */
    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

}
