// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.7.0;
import {SafeMath} from "./util/SafeMath.sol";
// import {BaseToken} from "./util/BaseToken.sol";
import {McoinTrc20} from "./util/McoinTrc20.sol";

struct BuyConfig {
    // uint256 price; // 价格
    uint256 true_rate; // 实际交易万分之几
    uint256 sell_max; // 最大卖出数量
    uint256 parent_asset_rate; // 上级资产奖励万分之几
    uint256 parent_stock_rate; // 上级股权奖励万分之几
    uint256 max_price_stock_rate; // 上级股权奖励万分之几
}

contract MdiDefi {
    address public stockTokenAddress; // 股权 Token地址 0k
    address public assetTokenAddress; // 接收资产的 Token地址 ok
    uint256 public baseTokenDecimals; // 资产与grc 的比例
    uint8 public dgrcDecimals = 6;
    uint8 public assetTokenDecimals = 6;
    uint8 public stockTokenDecimals = 6;
    address public adminAddress; // 管理员地址
    address public execAddress; // 执行地址

    mapping(address => uint256) balances; // dgrc余额
    mapping(address => uint256) asset_balances; // 资产 余额
    mapping(address => uint256) repeat_balances; // 复购 余额

    mapping(uint256 => BuyConfig) public buy_config; // 购买配套的配置 ok
    uint256[] public buy_prices; // 购买配套的配置 ok

    mapping(uint256 => mapping(address => uint256)) sells; // 全部的挂卖量
    mapping(uint256 => address[]) sell_address; // 全部的挂卖的地址集合
    mapping(uint256 => uint256) sell_price_amounts; // 每个价格的挂卖数量
    uint256[] public sell_prices; // 当前的数量集合
    uint256 public sell_min_prices = 20; // 当前的数量集合
    uint256 public sell_max_prices = 40; // 当前的数量集合

    mapping(address => uint256) buy_money_users; // 需要复购的会员与数量
    address[] public buy_users; // 需要复购的会员集合

    mapping(address => uint256) public user_sell_total; // 每个人挂卖的总量
    mapping(address => uint256) public user_sell_max; // 每个人最高的配套

    address[] users; // 所有会员的集合
    mapping(address => uint256) public user_splits; // 每会员的拆分次数
    mapping(address => address) public user_parents; // 上级信息集合

    uint256 start_balances = 6000000; // 发行总量

    uint256 public split_rate = 20000; // 拆分率 万分之几

    uint256 public min_sell_money = 100; // 最低卖出的数量

    uint256 public repeat_buy_min = 50; // 最低卖出的数量

    uint256 public fee_money = 0; // 平台的手续费

    uint256 public buy_rate_profit = 0; // 平台的配套利润

    // uint256 min_buy_money = 10000000; // 最低购买的数量

    uint8 public status = 1; // 状态 1 挂卖中 2购买中 3拆分中

    // 买入事件
    event BindParent(address indexed owner, address indexed parent);

    // 买入事件
    event Buy(address indexed owner, uint256 money);

    // 复购事件
    event RepeatBuy(address indexed owner, uint256 money);

    // 卖出事件
    event Sell(address indexed owner, uint256 price, uint256 amount);

    // 交易事件
    event Trade(
        address indexed sell,
        address indexed buy,
        uint256 price,
        uint256 amount,
        uint256 sellMoney,
        uint256 repeat
    );

    // 奖励
    event Bonus(address indexed parent, address indexed child, uint256 money);

    // 卖完事件
    event BuySuccess(address indexed adminAddress);

    constructor(
        address _assetTokenAddress,
        uint8 _assetTokenDecimals,
        address _stockTokenAddress,
        uint8 _stockTokenDecimals,
        address _adminAddress,
        address _execAddress
    ) {
        assetTokenAddress = _assetTokenAddress;
        stockTokenAddress = _stockTokenAddress;
        assetTokenDecimals = _assetTokenDecimals;
        stockTokenDecimals = _stockTokenDecimals;
        baseTokenDecimals = 10**(stockTokenDecimals - assetTokenDecimals + 2);
        if (baseTokenDecimals == 0) {
            baseTokenDecimals = 1;
        }
        adminAddress = _adminAddress; // 管理员
        execAddress = _execAddress; // 执行地址
        // 余额 全部给管理员
        balances[adminAddress] = SafeMath.mul(
            start_balances,
            10**uint256(dgrcDecimals)
        );

        // 最低卖出数量
        min_sell_money = SafeMath.mul(
            min_sell_money,
            10**uint256(assetTokenDecimals)
        );

        repeat_buy_min = SafeMath.mul(
            repeat_buy_min,
            10**uint256(assetTokenDecimals)
        );

        // 价格初始化
        for (uint256 j = sell_min_prices; j <= sell_max_prices; j++) {
            sell_prices.push(j);
        }

        _setBuyConfig(100, 7400, 400, 360, 20, 10);
        _setBuyConfig(200, 7800, 800, 360, 50, 20);
        _setBuyConfig(500, 8200, 2000, 420, 60, 30);
        _setBuyConfig(1000, 8600, 4000, 480, 80, 40);
        _setBuyConfig(2000, 9000, 8000, 540, 100, 50);
        _setBuyConfig(5000, 9400, 20000, 600, 120, 60);
        uint256[21] memory prs = [
            uint256(140000),
            uint256(150000),
            uint256(175000),
            uint256(185000),
            uint256(210000),
            uint256(250000),
            uint256(225000),
            uint256(325000),
            uint256(350000),
            uint256(375000),
            uint256(400000),
            uint256(350000),
            uint256(300000),
            uint256(275000),
            uint256(250000),
            uint256(275000),
            uint256(225000),
            uint256(175000),
            uint256(140000),
            uint256(125000),
            uint256(100000)
        ];
        // 挂卖
        for (uint256 j = 0; j < sell_prices.length; j++) {
            // uint256 d =  SafeMath.mul(20000, 10**uint256(dgrcDecimals));
            uint256 d = SafeMath.mul(prs[j], 10**uint256(dgrcDecimals));
            balances[adminAddress] = SafeMath.sub(balances[adminAddress], d); // 扣减
            sells[sell_prices[j]][adminAddress] = d; // 挂单
            sell_address[sell_prices[j]].push(adminAddress); // 挂单数量
            sell_price_amounts[sell_prices[j]] = SafeMath.add(
                sell_price_amounts[sell_prices[j]],
                d
            );
        }
        status = 3;
    }

    // 设置配套
    function setConfig(uint256 _min_sell_money, uint256 _repeat_buy_min, uint8 _status)
        public
        returns (bool)
    {
        require(msg.sender == adminAddress, "not auth");
        // 最低卖出数量
        min_sell_money = SafeMath.mul(
            _min_sell_money,
            10**uint256(assetTokenDecimals)
        );

        repeat_buy_min = SafeMath.mul(
            _repeat_buy_min,
            10**uint256(assetTokenDecimals)
        );
        status = _status;
        return true;
    }

    // 设置配套
    function setBuyConfig(
        uint256 price,
        uint256 true_rate,
        uint256 sell_max,
        uint256 parent_asset_rate,
        uint256 parent_stock_rate,
        uint256 max_price_stock_rate
    ) public returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        return
            _setBuyConfig(
                price,
                true_rate,
                sell_max,
                parent_asset_rate,
                parent_stock_rate,
                max_price_stock_rate
            );
    }

    // 设置配套
    function _setBuyConfig(
        uint256 price,
        uint256 true_rate,
        uint256 sell_max,
        uint256 parent_asset_rate,
        uint256 parent_stock_rate,
        uint256 max_price_stock_rate
    ) private returns (bool) {
        buy_config[price] = BuyConfig(
            true_rate,
            sell_max,
            parent_asset_rate,
            parent_stock_rate,
            max_price_stock_rate
        );
        if (SafeMath.indexOf(buy_prices, price) == uint256(-1)) {
            buy_prices.push(price);
        }
        return true;
    }

    // 获取配套详情
    function repeatBalancesOf(address owner) public view returns (uint256) {
        return repeat_balances[owner];
    }

    // 获取配套详情
    function sellTotalMax(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory ret = new uint256[](4);
        ret[0] = user_sell_total[owner];
        ret[1] = user_sell_max[owner];
        return ret;
    }

    // 获取 配套信息
    function getBuyPrices() public view returns (uint256[] memory) {
        return buy_prices;
    }

    // 获取配套详情
    function getBuyPricesConfig(uint256 price)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory ret = new uint256[](5);
        ret[0] = buy_config[price].true_rate;
        ret[1] = buy_config[price].sell_max;
        ret[2] = buy_config[price].parent_asset_rate;
        ret[3] = buy_config[price].parent_stock_rate;
        ret[4] = buy_config[price].max_price_stock_rate;
        return ret;
    }

    // 获取当前价格的挂单数量
    function getSellAmountsByPrice(uint256 price)
        public
        view
        returns (uint256)
    {
        return sell_price_amounts[price];
    }

    // 获取 价格区间
    function getSellPriceAmounts() public view returns (uint256[] memory) {
        uint256[] memory ret = new uint256[](sell_prices.length);
        for (uint256 i = 0; i < sell_prices.length; i++) {
            ret[i] = sell_price_amounts[sell_prices[i]];
        }
        return ret;
    }

    // 获取 价格区间
    function getSellPrices() public view returns (uint256[] memory) {
        return sell_prices;
    }

    // 获取会员
    function getSellByPriceAddress(uint256 price, address owner)
        public
        view
        returns (uint256)
    {
        return sells[price][owner];
    }

    // 获取挂卖情况
    function getSellByAddress(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory ret = new uint256[](sell_prices.length);
        for (uint256 i = 0; i < sell_prices.length; i++) {
            ret[i] = sells[sell_prices[i]][owner];
        }
        return ret;
    }

    // 复购
    function repeatBuy() public returns (bool) {
        require(status == 2, "not start"); // 当前不能挂卖
        uint256 money = repeat_balances[msg.sender];
        require(money >= repeat_buy_min, "Min Money"); // 必须是对应的配套
        // 属于配套
        uint256 send_money = money; // 实际购买资产数量

        // 将复购余额设置为0
        repeat_balances[msg.sender] = 0;
        // ERC20合约
        McoinTrc20 baseToken = McoinTrc20(assetTokenAddress);

        // 手续费 10%
        fee_money = SafeMath.add(
            fee_money,
            SafeMath.div(SafeMath.mul(send_money, 10), 100)
        );

        // 吃交易
        for (uint256 i = 0; i < sell_prices.length; i++) {
            uint256 price = sell_prices[i];
            if (send_money <= 0) {
                break;
            }
            // 该价位已经卖完了
            if (sell_price_amounts[price] == 0) {
                continue;
            }
            // 当前价格下 可购买的数量
            uint256 ss_amount = SafeMath.div(
                SafeMath.mul(send_money, baseTokenDecimals),
                price
            );
            // 查询该价位所有的挂单数量
            for (uint256 j = 0; j < sell_address[price].length; j++) {
                address sell_add = sell_address[price][j];

                // 该地址已经卖完了
                if (sells[price][sell_add] == 0) {
                    continue;
                }
                // 吃干净
                uint256 uu_amount;
                uint256 uu_money;
                if (ss_amount <= sells[price][sell_add]) {
                    uu_amount = ss_amount;
                    uu_money = send_money;
                } else {
                    uu_amount = sells[price][sell_add];
                    uu_money = SafeMath.div(
                        SafeMath.mul(uu_amount, price),
                        baseTokenDecimals
                    ); // 成交金额
                }

                balances[msg.sender] = SafeMath.add(
                    balances[msg.sender],
                    uu_amount
                ); // 购买回来了
                sells[price][sell_add] = SafeMath.sub(
                    sells[price][sell_add],
                    uu_amount
                ); // 卖了多少就减多少
                sell_price_amounts[price] = SafeMath.sub(
                    sell_price_amounts[price],
                    uu_amount
                ); // 更新每个价位的卖出量

                // 剩余数量
                ss_amount = SafeMath.sub(ss_amount, uu_amount);
                // 剩余金额
                send_money = SafeMath.sub(send_money, uu_money);

                // 需要转账给卖家的金额
                uint256 u_money = SafeMath.div(
                    SafeMath.mul(uu_money, sell_add == adminAddress ? 90 : 60),
                    100
                );
                // 转账给卖家
                require(baseToken.transfer(sell_add, u_money), "money not");
                // asset_balances[sell_add] = SafeMath.add(asset_balances[sell_add], u_money);

                emit Trade(sell_add, msg.sender, price, uu_amount, u_money, 1);
                // 管理员不需要复购
                if (sell_add == adminAddress) {
                    if (ss_amount <= 0) {
                        break;
                    }
                    continue;
                }
                repeat_balances[sell_add] = SafeMath.add(
                    repeat_balances[sell_add],
                    SafeMath.div(SafeMath.mul(uu_money, 30), 100)
                );

                // 已卖完
                if (ss_amount <= 0) {
                    break;
                }
            }
        }
        // 本轮已经卖完了 购买 系统的配额
        if (send_money > 0) {
            uint256 ss_amount = SafeMath.div(
                SafeMath.mul(send_money, baseTokenDecimals),
                sell_prices[sell_prices.length - 1]
            );
            // 全部购买完
            balances[msg.sender] = SafeMath.add(
                balances[msg.sender],
                ss_amount
            ); // 购买回来了
            balances[adminAddress] = SafeMath.sub(
                balances[adminAddress],
                ss_amount
            ); // 购买回来了
            // 需要转账给卖家的金额
            uint256 u_money = SafeMath.div(SafeMath.mul(send_money, 90), 100);
            // 转账给卖家
            require(baseToken.transfer(adminAddress, u_money), "money not");

            send_money = 0;
            emit Trade(
                adminAddress,
                msg.sender,
                sell_prices[sell_prices.length - 1],
                ss_amount,
                u_money,
                1
            );
            // 卖完了
            emit BuySuccess(adminAddress);

            // 卖完了
            status = 3;
        }

        emit RepeatBuy(msg.sender, money);
        return true;
    }

    // 购买 输入金额购买
    function buy(uint256 money, address parent) external returns (bool) {
        require(status == 2, "not start"); // 当前不能挂卖

        require(buy_config[money].true_rate > 0, "Money Error"); // 必须是对应的配套
        // 属于配套

        uint256 this_money = 0; // 平台待管的
        uint256 all_money = SafeMath.mul(money, 10**assetTokenDecimals); // 实际购买资产数量
        uint256 send_money = SafeMath.div(
            SafeMath.mul(all_money, buy_config[money].true_rate),
            10000
        ); // 实际购买金额
        uint256 admin_profit = SafeMath.sub(all_money, send_money); // 实际购买资产数量

        // ERC20合约
        McoinTrc20 baseToken = McoinTrc20(assetTokenAddress);
        McoinTrc20 stockToken = McoinTrc20(stockTokenAddress);

        // 检查授权
        require(
            baseToken.allowance(msg.sender, address(this)) >= all_money,
            "please allowance to"
        );

        // 检查余额
        require(baseToken.balanceOf(msg.sender) >= all_money, "money not");

        // 手续费 10%
        fee_money = SafeMath.add(
            fee_money,
            SafeMath.div(SafeMath.mul(send_money, 10), 100)
        );
        uint256 max_price = 0;
        // 吃交易
        for (uint256 i = 0; i < sell_prices.length; i++) {
            uint256 price = sell_prices[i];
            if (send_money <= 0) {
                break;
            }
            // 该价位已经卖完了
            if (sell_price_amounts[price] == 0) {
                continue;
            }
            // 当前价格下 可购买的数量
            uint256 ss_amount = SafeMath.div(
                SafeMath.mul(send_money, baseTokenDecimals),
                price
            );
            // 查询该价位所有的挂单数量
            for (uint256 j = 0; j < sell_address[price].length; j++) {
                address sell_add = sell_address[price][j];

                // 该地址已经卖完了
                if (sells[price][sell_add] == 0) {
                    continue;
                }
                // 吃干净
                uint256 uu_amount;
                uint256 uu_money;
                if (ss_amount <= sells[price][sell_add]) {
                    uu_amount = ss_amount;
                    uu_money = send_money;
                } else {
                    uu_amount = sells[price][sell_add];
                    uu_money = SafeMath.div(
                        SafeMath.mul(uu_amount, price),
                        baseTokenDecimals
                    ); // 成交金额
                }

                // 购买的数量
                balances[msg.sender] = SafeMath.add(
                    balances[msg.sender],
                    uu_amount
                ); 
                // 卖出减少
                sells[price][sell_add] = SafeMath.sub(
                    sells[price][sell_add],
                    uu_amount
                ); // 卖了多少就减多少
                sell_price_amounts[price] = SafeMath.sub(
                    sell_price_amounts[price],
                    uu_amount
                ); // 更新每个价位的卖出量

                // 剩余数量
                ss_amount = SafeMath.sub(ss_amount, uu_amount);
                // 剩余金额
                send_money = SafeMath.sub(send_money, uu_money);

                // 需要转账给卖家的金额
                uint256 u_money = SafeMath.div(
                    SafeMath.mul(uu_money, sell_add == adminAddress ? 90 : 60),
                    100
                );
                // 转账给卖家
                require(
                    baseToken.transferFrom(msg.sender, sell_add, u_money),
                    "money not"
                );
                // asset_balances[sell_add] = SafeMath.add(asset_balances[sell_add], u_money);

                // 由平台待保管的
                this_money = SafeMath.add(
                    this_money,
                    SafeMath.sub(uu_money, u_money)
                );

                max_price = price;
                emit Trade(sell_add, msg.sender, price, uu_amount, u_money, 0);
                // 管理员不需要复购
                if (sell_add == adminAddress) {
                    if (ss_amount <= 0) {
                        break;
                    }
                    continue;
                }

                // 更新会员复购的数量
                repeat_balances[sell_add] = SafeMath.add(
                    repeat_balances[sell_add],
                    SafeMath.div(SafeMath.mul(uu_money, 30), 100)
                );

                // 已卖完
                if (ss_amount <= 0) {
                    break;
                }
            }
        }
        // 本轮已经卖完了 购买 系统的配额
        if (send_money > 0) {
            // 当前可购买的数量已最高价购买
            // uint256 ss_amount = SafeMath.div(send_money, SafeMath.mul(sell_prices[sell_prices.length -1], baseTokenDecimals));
            uint256 ss_amount = SafeMath.div(
                SafeMath.mul(send_money, baseTokenDecimals),
                sell_prices[sell_prices.length - 1]
            );
            // 全部购买完
            balances[msg.sender] = SafeMath.add(
                balances[msg.sender],
                ss_amount
            ); // 购买回来了
            balances[adminAddress] = SafeMath.sub(
                balances[adminAddress],
                ss_amount
            ); // 购买回来了
            // 需要转账给卖家的金额
            uint256 u_money = SafeMath.div(SafeMath.mul(send_money, 90), 100);
            // 转账给卖家
            require(
                baseToken.transferFrom(msg.sender, adminAddress, u_money),
                "money not"
            );
            // asset_balances[adminAddress] = SafeMath.add(asset_balances[adminAddress], u_money);
            // 由平台待保管的
            this_money = SafeMath.add(
                this_money,
                SafeMath.sub(send_money, u_money)
            );
            // // 手续费
            // fee_money = SafeMath.add(fee_money, SafeMath.div(SafeMath.mul( send_money , 10), 100));
            send_money = 0;
            emit Trade(
                adminAddress,
                msg.sender,
                sell_prices[sell_prices.length - 1],
                ss_amount,
                u_money,
                0
            );
            // 卖完了
            emit BuySuccess(adminAddress);
            // 卖完了
            status = 3;
        }

        // 购买4块的奖励
        if (sell_prices[sell_prices.length - 1] == max_price) {
            // ERC20合约
            uint256 quanBonus = SafeMath.div(
                SafeMath.mul(
                    SafeMath.mul(money, 10**stockTokenDecimals),
                    buy_config[money].max_price_stock_rate
                ),
                10000
            );
            stockToken.mining(user_parents[msg.sender], quanBonus);
        }

        // 绑定上级
        if (
            user_parents[msg.sender] == address(0) &&
            parent != msg.sender &&
            parent != address(0) &&
            balances[parent] > 0
        ) {
            user_parents[msg.sender] = parent;
            emit BindParent(msg.sender, parent);
        }

        // 添加配套限制
        if (
            user_sell_max[msg.sender] <
            SafeMath.mul(buy_config[money].sell_max, 10**assetTokenDecimals)
        ) {
            user_sell_max[msg.sender] = SafeMath.mul(
                buy_config[money].sell_max,
                10**assetTokenDecimals
            );
        }

        // 上级奖励
        if (user_parents[msg.sender] != address(0)) {
            uint256 bonus = SafeMath.div(
                SafeMath.mul(all_money, buy_config[money].parent_asset_rate),
                10000
            );
            require(
                baseToken.transferFrom(
                    msg.sender,
                    user_parents[msg.sender],
                    bonus
                ),
                "money not"
            );
            admin_profit = SafeMath.sub(admin_profit, bonus);

            // 奖励股份
            bonus = SafeMath.div(
                SafeMath.mul(all_money, buy_config[money].parent_stock_rate),
                10000
            );
            stockToken.mining(user_parents[msg.sender], bonus);
            emit Bonus(user_parents[msg.sender], msg.sender, money);
        }

        buy_rate_profit = SafeMath.add(buy_rate_profit, admin_profit);
        // 平台利润
        this_money = SafeMath.add(this_money, admin_profit);
        // 转账给平台的
        require(
            baseToken.transferFrom(msg.sender, address(this), this_money),
            "money not"
        );
        // require(baseToken.transferFrom(msg.sender, address(this) , all_money), 'money not');

        emit Buy(msg.sender, all_money);
        return true;
    }

    // 挂卖
    function sell(uint256 price, uint256 amount) external returns (bool) {
        require(status == 1, "not start"); // 当前不能挂卖
        // uint256 trueAmount = SafeMath.mul(amount, 10 ** dgrcDecimals);
        require(balances[msg.sender] > amount, "balance min"); // 余额不够

        require(
            price >= sell_min_prices && price <= sell_max_prices,
            "price select Error"
        ); // 必须是规定的价格

        require(sells[price][msg.sender] == 0, "use Sell Price"); // 一个价位只能挂卖一次

        // 计算卖出价格
        uint256 sell_money = SafeMath.div(
            SafeMath.mul(amount, price),
            baseTokenDecimals
        );

        require(sell_money >= min_sell_money, "min sell"); // 最低要10个起卖

        require(
            user_sell_max[msg.sender] >=
                SafeMath.add(user_sell_total[msg.sender], sell_money),
            "user_sell_max sell"
        ); // 配套限额
        user_sell_total[msg.sender] = SafeMath.add(
            user_sell_total[msg.sender],
            sell_money
        ); // 配套限制

        balances[msg.sender] = SafeMath.sub(balances[msg.sender], amount); // 扣减

        sells[price][msg.sender] = amount; // 挂单
        sell_address[price].push(msg.sender); // 排序
        sell_price_amounts[price] = SafeMath.add(
            sell_price_amounts[price],
            amount
        ); // 各个价位可查看的数量

        emit Sell(msg.sender, price, amount);
        return true;
    }

    // 拆分
    function bonusParent(
        address[] memory owners,
        uint256[] memory assets,
        uint256[] memory stocks
    ) external returns (bool) {
        require(status == 3, "not start"); // 当前不能挂卖
        require(msg.sender == execAddress, "not auth");
        // ERC20合约
        McoinTrc20 baseToken = McoinTrc20(assetTokenAddress);
        McoinTrc20 stockToken = McoinTrc20(stockTokenAddress);
        for (uint256 i = 0; i < owners.length; i++) {
            // 转账
            if (assets[i] > 0) {
                require(baseToken.transfer(owners[i], assets[i]), "money not");
            }
            // 转账
            if (stocks[i] > 0) {
                stockToken.mining(owners[i], stocks[i]);
            }
        }
        return true;
    }

    // 拆分
    function split(address[] memory owners, uint256[] memory new_balances)
        external
        returns (bool)
    {
        require(status == 3, "not start"); // 当前不能挂卖
        require(msg.sender == execAddress, "not auth");
        for (uint256 i = 0; i < owners.length; i++) {
            balances[owners[i]] = new_balances[i];
            user_sell_total[owners[i]] = 0;
        }
        return true;
    }

    // 完成拆分 开始挂卖
    function splitSuccess() external returns (bool) {
        require(status == 3, "not start"); // 当前不能挂卖
        require(msg.sender == execAddress, "not auth");

        // 清除各个价位的地址
        for (uint256 i = 0; i < sell_prices.length; i++) {
            delete sell_address[sell_prices[i]];
            delete sell_price_amounts[sell_prices[i]];
        }

        delete sell_prices;
        // 重新释放价格
        for (uint256 j = sell_min_prices; j <= sell_max_prices; j++) {
            sell_prices.push(j);
        }
        status = 1;
        return true;
    }

    // // 完成拆分 开始挂卖
    // function startStatus(uint8 _status) external returns (bool) {
    //     require(msg.sender == execAddress, "not auth");
    //     status = _status;
    //     return true;
    // }

    // 购买时间到 开放购买
    function buyStart(
        uint256 _split,
        uint256 min_price,
        uint256 max_price
    ) external returns (bool) {
        require(msg.sender == execAddress, "not auth");
        require(status == 1, "not start"); // 当前不能挂卖
        sell_min_prices = min_price;
        sell_max_prices = max_price;
        split_rate = _split;
        status = 2;
        return true;
    }

    // 查看余额
    function balanceOf(address owner) public view returns (uint256) {
        return balances[owner];
    }

    // 复购余额
    function repeatBalanceOf(address owner) public view returns (uint256) {
        return repeat_balances[owner];
    }

    // // 更改管理员
    // function updateAdmin(address newAdmin, address _execAddress) public returns (bool) {
    //     require(msg.sender == adminAddress, "not auth");
    //     // balances[newAdmin] = SafeMath.add(
    //     //     balances[newAdmin],
    //     //     balances[msg.sender]
    //     // );
    //     // balances[msg.sender] = 0;
    //     adminAddress = newAdmin;
    //     execAddress = _execAddress;
    //     return true;
    // }


    // 合约余额提现
    function withDraw(address payable to) public returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        require(address(this).balance > 0, "not balance");
        to.transfer(address(this).balance);
        return true;
    }

    // 合约余额提现
    function withDrawToken(address tokenAddress, uint256 money) public returns (bool) {
        require(msg.sender == adminAddress, "not auth");
        McoinTrc20 baseToken = McoinTrc20(tokenAddress);
        baseToken.transfer(adminAddress, money);
        return true;
    }

      // 发放手续费
    function splitFee(address[] memory owners, uint256[] memory moneys)
        external
        returns (bool)
    {
        require(msg.sender == execAddress, "not auth");
        uint256 max_moneys = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            max_moneys = SafeMath.add(max_moneys, moneys[i]);

        }
        require(max_moneys <= fee_money, "balance not");
        fee_money =  SafeMath.sub(fee_money, max_moneys);
        McoinTrc20 baseToken = McoinTrc20(assetTokenAddress);
        for (uint256 i = 0; i < owners.length; i++) {
            baseToken.transfer(owners[i], moneys[i]);
        }
        return true;
    }
}
