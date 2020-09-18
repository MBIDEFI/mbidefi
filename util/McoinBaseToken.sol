// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.7.0;

abstract contract McoinBaseToken {
    address public mbidefiTokenAddress;
    address public assetTokenAddress;
    uint256 public sell_max;
    uint256 public sell_current = 0;
    uint256 public mining_max = 0;
    uint256 public mining_current = 0;
    uint256 public admin_rate = 25;

    uint256 public totalSupply;
    address public adminAddress; // 管理员地址
    uint8 public decimals; // 小数点
    string public name; // 名称
    string public symbol; //token代号: eg SBX
    mapping(address => uint256) balances; // 账户余额

    mapping(address => mapping(address => uint256)) allowed; // 代理余额

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // 
    event Buy(address indexed burner, uint256 value);
    event Mining(address indexed burner, uint256 value);

    // 销毁
    event Burn(address indexed burner, uint256 value);

    // 增发
    event Increases(address indexed burner, uint256 value);

    // 挖矿
    function mining(
        address to,
        uint256 money
    ) external virtual returns (bool);
    // 购买
    function buy(
        uint256 money
    ) external virtual returns (bool);

    function setMbi(
        address _mbidefiTokenAddress,
        address _assetTokenAddress,
        uint256 _sell_max,
        uint256 _mining_max,
        uint256 _admin_rate
    ) external virtual returns (bool);

    function balanceOf(address owner) public virtual view returns (uint256);

    function transfer(address to, uint256 value)
        external
        virtual
        returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external virtual returns (bool);

    function approve(address spender, uint256 value)
        external
        virtual
        returns (bool);

    function allowance(address owner, address spender)
        public
        virtual
        view
        returns (uint256);
}
