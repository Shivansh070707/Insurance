// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Reward is ERC20, Ownable {
    constructor() ERC20("Reward", "RWD") {}

    function mint(address to, uint value) external onlyOwner {
        _mint(to, value);
    }

    function burn(address to, uint amount) external onlyOwner {
        _burn(to, amount);
    }
}
