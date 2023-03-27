// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StETh is ERC20 {
    constructor() ERC20("stETH", "stETH") {}

    function submit(address to) external payable {
        _mint(to, msg.value);
    }

    function burn(address to, uint amount) external {
        _burn(to, amount);
    }
}
