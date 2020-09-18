// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.7.0;

import {SafeMath} from "./util/SafeMath.sol";
import {McoinBaseToken} from "./util/McoinBaseToken.sol";

contract McoinErc20Token is McoinBaseToken {

    
    // 设置MBI 的管理员
    function setMbi(
        address _mbidefiTokenAddress,
        address _assetTokenAddress,
        uint256 _sell_max,
        uint256 _mining_max,
        uint256 _admin_rate
    ) external virtual override returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        mbidefiTokenAddress = _mbidefiTokenAddress;
        assetTokenAddress = _assetTokenAddress;
        sell_max = _sell_max;
        mining_max = _mining_max;
        admin_rate = _admin_rate;
        return true;
    }

    // 挖矿
    function mining(address to, uint256 money)
        external
        virtual
        override
        returns (bool)
    {
        require(msg.sender == mbidefiTokenAddress, "not auth");
        if (mining_max < SafeMath.add(mining_current, money)) {
            return false;
        }
        // 卖出数量增加
        mining_current = SafeMath.add(mining_current, money);

        // 余额增加
        balances[to] = SafeMath.add(balances[to], money);

        // 管理员增加
        uint256 admin_money = SafeMath.div(SafeMath.mul(money, admin_rate), 100);
        balances[adminAddress] = SafeMath.add( balances[adminAddress],admin_money );

        // 总量增加
        totalSupply = SafeMath.add(totalSupply,  SafeMath.add(money, admin_money));
        emit Mining(to, money);
        return true;
    }

    // 使用USDT购买
    function buy(uint256 money) external virtual override returns (bool) {
        require(sell_max > SafeMath.add(sell_current, money), "sell ok");

        // ERC20合约
        McoinBaseToken baseToken = McoinBaseToken(assetTokenAddress);
        // 检查授权
        require(
            baseToken.allowance(msg.sender, address(this)) >= money,
            "please allowance to"
        );
        // 检查余额
        require(baseToken.balanceOf(msg.sender) >= money, "money not");

        // 转账到平台
        require(
            baseToken.transferFrom(msg.sender, address(this), money),
            "money not"
        );
        // 卖出数量增加
        sell_current = SafeMath.add(sell_current, money);
        
        // 余额增加
        balances[msg.sender] = SafeMath.add(balances[msg.sender], money);

        uint256 admin_money = SafeMath.div(SafeMath.mul(money, admin_rate), 100);
        // 管理员增加
        balances[adminAddress] = SafeMath.add( balances[adminAddress], admin_money );

        totalSupply = SafeMath.add(totalSupply,  SafeMath.add(money, admin_money));
        emit Buy(msg.sender, money);
        return true;
    }

    constructor(
        uint256 _initialAmount,
        uint8 _decimalUnits,
        string memory _tokenName,
        string memory _tokenSymbol,
        address _adminAddress
    ) {
        totalSupply = SafeMath.mul(_initialAmount, 10**uint256(_decimalUnits)); // 设置初始总量
        balances[_adminAddress] = totalSupply; // 初始token数量给予消息发送者
        adminAddress = _adminAddress; // 设置管理员
        name = _tokenName; // token名称
        decimals = _decimalUnits; // 小数位数
        symbol = _tokenSymbol; // token简称
    }

    function transfer(address to, uint256 value)
        external
        virtual
        override
        returns (bool success)
    {
        require(to != address(0), "to not address");
        require(balances[msg.sender] >= value, "lack of balance");
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], value);

        balances[to] = SafeMath.add(balances[to], value);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external virtual override returns (bool) {
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

    function balanceOf(address owner) public override view returns (uint256) {
        return balances[owner];
    }

    // 授权
    function approve(address spender, uint256 value)
        public
        override
        returns (bool)
    {
        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // 获取授权余额
    function allowance(address owner, address spender)
        public
        override
        view
        returns (uint256)
    {
        return allowed[owner][spender];
    }

    // 更改管理员
    function updateAdmin(address newAdmin) public returns (bool) {
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
        public
        payable
        returns (bool)
    {
        require(msg.sender == adminAddress, "not auth");
        require(_tos.length == _moneys.length, "length error");
        uint256 sumMoney = 0;
        for (uint256 index = 0; index < _moneys.length; index++) {
            sumMoney = SafeMath.add(sumMoney, _moneys[index]);
        }
        totalSupply = SafeMath.add(totalSupply, sumMoney);
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
        public
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
    function withDraw(address payable _to) public returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        require(address(this).balance > 0, "not balance");
        _to.transfer(address(this).balance);
        return true;
    }

    // 合约余额提现
    function withDrawAsset(uint256 money) public returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        McoinBaseToken baseToken = McoinBaseToken(assetTokenAddress);
        baseToken.transfer(adminAddress, money);
        return true;
    }
    
    // 销毁合约
    function kill() external returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        selfdestruct(msg.sender);
        return true;
    }
}
