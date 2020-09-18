// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.7.0;

import {ITRC20} from "./ITRC20.sol";
import {SafeMath} from "./SafeMath.sol";

contract BaseToken is ITRC20 {
    uint256 _totalSupply;
    address public adminAddress; // 管理员地址
    uint8 public decimals; // 小数点
    string public name; // 名称
    string public symbol; //token代号: eg SBX
    mapping(address => uint256) balances; // 账户余额

    mapping(address => mapping(address => uint256)) allowed; // 代理余额

    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }

    function transfer(address to, uint256 value)
        external
        override
        returns (bool)
    {
        require(to != address(0), "to not address");
        require(balances[msg.sender] >= value, "lack of balance");
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], value);

        balances[to] = SafeMath.add(balances[to], value);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        require(
            balances[from] >= value && allowed[from][msg.sender] >= value,
            "lack of balance"
        );
        balances[to] = SafeMath.add(balances[to], value);
        allowed[from][msg.sender] = SafeMath.sub(
            allowed[from][msg.sender],
            value
        );
        balances[from] = SafeMath.sub(balances[from], value);
        emit Transfer(from, to, value);
        return true;
    }

    function balanceOf(address who) external override view returns (uint256) {
        return balances[who];
    }

    function allowance(address owner, address spender)
        external
        override
        view
        returns (uint256)
    {
        return allowed[owner][spender];
    }
}
