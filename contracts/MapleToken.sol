// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import "./ERC2222.sol";

contract MapleToken is ERC2222 {

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant  PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    mapping (address => uint256) public nonces;

    /**
        @dev Instanties the MapleToken.
        @param name       Name of the token.
        @param symbol     Symbol of the token.
        @param fundsToken The asset claimable / distributed via ERC-2222, deposited to MapleToken contract.
    */
    constructor (
        string memory name,
        string memory symbol,
        address fundsToken
    ) ERC2222(name, symbol, fundsToken) public {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );

        require(address(fundsToken) != address(0), "MapleToken:INVALID_FUNDS_TOKEN");
        _mint(msg.sender, 10000000 * (10 ** uint256(decimals())));
    }

    /**
        @dev Approve by signature.
        @param owner    Owner address that signed the permit
        @param spender  Spender of the permit
        @param value    Permit approval spend limit
        @param deadline Deadline after which the permit is invalid
        @param v        ECDSA signature v component
        @param r        ECDSA signature r component
        @param s        ECDSA signature s component
    */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'MapleToken:EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'MapleToken:INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
}
