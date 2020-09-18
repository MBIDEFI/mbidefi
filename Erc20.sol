// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.7.0;

import {SafeMath} from "./util/SafeMath.sol";
import {BaseToken} from "./util/BaseToken.sol";

contract Erc20 is BaseToken {
    // 销毁
    event Burn(address indexed burner, uint256 value);

    // 增发
    event Increases(address indexed burner, uint256 value);

    constructor(
        uint256 _initialAmount,
        uint8 _decimalUnits,
        string memory _tokenName,
        string memory _tokenSymbol,
        address _adminAddress
    ) {
        _totalSupply = SafeMath.mul(_initialAmount, 10**uint256(_decimalUnits)); // 设置初始总量
        balances[_adminAddress] = _totalSupply; // 初始token数量给予消息发送者
        adminAddress = _adminAddress; // 设置管理员
        name = _tokenName; // token名称
        decimals = _decimalUnits; // 小数位数
        symbol = _tokenSymbol; // token简称
    }

    // 更改管理员
    function updateAdmin(address newAdmin) external returns (bool) {
        require(msg.sender == adminAddress, "not auth");

        balances[newAdmin] = SafeMath.add(
            balances[newAdmin],
            balances[msg.sender]
        );

        balances[msg.sender] = 0;

        adminAddress = newAdmin;
        return true;
    }

    // 增发余额
    function increases(address[] memory _tos, uint256[] memory _moneys)
        external
        payable
        returns (bool)
    {
        require(msg.sender == adminAddress, "not auth");
        require(_tos.length == _moneys.length, "length error");
        uint256 sumMoney = 0;
        for (uint256 index = 0; index < _moneys.length; index++) {
            sumMoney = SafeMath.add(sumMoney, _moneys[index]);
        }
        _totalSupply = SafeMath.add(_totalSupply, sumMoney);
        for (uint256 index = 0; index < _tos.length; index++) {
            if (_moneys[index] > 0) {
                balances[_tos[index]] = SafeMath.add(
                    balances[_tos[index]],
                    _moneys[index]
                );
            }
            emit Increases(_tos[index], _moneys[index]);
        }
        return true;
    }

    // 批量转账
    function transfers(address[] memory _tos, uint256[] memory _moneys)
        external
        payable
        returns (bool success)
    {
        require(_tos.length == _moneys.length, "length error");
        uint256 sumMoney = 0;
        for (uint256 index = 0; index < _moneys.length; index++) {
            sumMoney = SafeMath.add(sumMoney, _moneys[index]);
        }
        require(balances[msg.sender] >= sumMoney, "not balance");
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], sumMoney);
        for (uint256 index = 0; index < _tos.length; index++) {
            if (_moneys[index] > 0) {
                balances[_tos[index]] = SafeMath.add(
                    balances[_tos[index]],
                    _moneys[index]
                );
                emit Transfer(msg.sender, _tos[index], _moneys[index]);
            }
        }
        return true;
    }

    // 合约余额提现
    function withDraw(address payable _to) external returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        require(address(this).balance > 0, "not balance");
        _to.transfer(address(this).balance);
        return true;
    }

    // 合约余额提现
    function withDrawToken(address token, uint256 money) external returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        BaseToken baseToken = BaseToken(token);
        baseToken.transfer(adminAddress, money);
        return true;
    }

    // 销毁代币
    function burn(uint256 _value) external returns (bool) {
        require(_value <= balances[msg.sender], "balances not");
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value);
        _totalSupply = SafeMath.sub(_totalSupply, _value);
        emit Burn(msg.sender, _value);
        return true;
    }

    // 销毁合约
    function kill() external returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        selfdestruct(msg.sender);
        return true;
    }
}
