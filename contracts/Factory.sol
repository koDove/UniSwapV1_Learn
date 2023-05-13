//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "./Exchange.sol";

contract Factory {
    mapping(address => address) tokenToExchange; //토큰 주소를 넣었을 때 exchange주소를 반환

    function createExchange(address _token) public returns (address) {
        Exchange exchange = new Exchange(_token);
        tokenToExchange[_token] = address(exchange);

        return address(exchange);
    }

    function getExchange(address _token) public view returns (address) {
        return tokenToExchange[_token];
    }
}
