// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Isteth {
    function submit(address _referral) external payable returns (uint256);

    function transfer(address receipent, uint amount) external;

    function balanceOf(address) external view returns (uint);

    function transferFrom(address, address, uint) external;

    function approve(address, uint) external;

    function allowance(address, address) external view returns (uint);
}

interface IReward {
    function mint(address to, uint amount) external;
}

contract InsuranceVault {
    struct Product {
        string name;
        uint productId;
        uint256 riskLevel;
        uint256 premium;
        uint256 totalCapital;
    }

    address public lidoAddress = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    uint8 public inflationRate = 10; // 10% per year

    Isteth public stETH;
    IReward public reward;

    mapping(address => Product[]) public _optInProducts;
    mapping(address => mapping(uint => uint)) public userShares;
    mapping(uint256 => Product) public products;
    mapping(address => mapping(uint256 => bool)) public optIns;
    mapping(address => uint256) public lastOptInTime;

    event OptInOut(address indexed user, uint256 indexed productId, bool optIn);
    event Deposit(
        address indexed user,
        uint256 indexed productId,
        uint256 amount
    );
    event Withdraw(
        address indexed user,
        uint256 indexed productId,
        uint256 amount
    );

    constructor(address _stETH, address _reward) {
        stETH = Isteth(_stETH);
        reward = IReward(_reward);
    }

    function buySteth() public payable {
        uint tokens = stETH.submit{value: msg.value}(address(0));
        stETH.transfer(msg.sender, tokens);
    }

    function stEthBal() external view returns (uint) {
        return stETH.balanceOf(msg.sender);
    }

    function allowanceStEth(
        address owner,
        address spender
    ) external view returns (uint) {
        return stETH.allowance(owner, spender);
    }

    function optedInProducts(
        address user
    ) public view returns (Product[] memory) {
        return _optInProducts[user];
    }

    function addProduct(
        string memory name,
        uint productId,
        uint256 riskLevel,
        uint256 premium
    ) public {
        Product memory newProduct = Product(
            name,
            productId,
            riskLevel,
            premium,
            0
        );
        products[productId] = newProduct;
    }

    function modifyProduct(
        uint256 productId,
        string memory name,
        uint256 riskLevel,
        uint256 premium
    ) public {
        require(
            productId == products[productId].productId,
            "Product does not exist"
        );
        products[productId].name = name;
        products[productId].riskLevel = riskLevel;
        products[productId].premium = premium;
    }

    function deleteProduct(uint256 productId) public {
        require(
            productId == products[productId].productId,
            "Product does not exist"
        );
        delete products[productId];
    }

    function optInOutProduct(uint256 productId, bool optIn) public payable {
        require(
            productId == products[productId].productId,
            "Product does not exist"
        );
        require(
            block.timestamp > lastOptInTime[msg.sender],
            "Opt-in cooldown period has not elapsed"
        );
        optIns[msg.sender][productId] = optIn;
        lastOptInTime[msg.sender] = block.timestamp;
        if (optIn) {
            require(
                msg.value >= products[productId].premium,
                "Not enough premium"
            );
            _optInProducts[msg.sender].push(products[productId]);
        } else {
            Product[] storage temp = _optInProducts[msg.sender];
            for (uint i = 0; i < temp.length; i++) {
                if (temp[i].productId == productId) {
                    temp[i] = temp[temp.length - 1];
                    temp.pop();
                    break;
                }
            }
        }

        emit OptInOut(msg.sender, productId, optIn);
    }

    function deposit(uint256 productId, uint256 amount) public payable {
        require(
            products[productId].productId == productId,
            "Product does not exist"
        );
        require(optIns[msg.sender][productId], "User has not opted in");
        stETH.transferFrom(msg.sender, address(this), amount);
        userShares[msg.sender][productId] += amount;
        products[productId].totalCapital += amount;
        emit Deposit(msg.sender, productId, amount);
    }

    function withdraw(uint256 productId, uint256 amount) public {
        require(
            products[productId].productId == productId,
            "Product does not exist"
        );
        require(
            userShares[msg.sender][productId] >= amount,
            "Insufficient balance"
        );
        uint rewardTokens = calculateRewards(msg.sender);
        userShares[msg.sender][productId] -= amount;
        products[productId].totalCapital -= amount;
        stETH.transfer(msg.sender, amount);
        reward.mint(msg.sender, rewardTokens);
        emit Withdraw(msg.sender, productId, amount);
    }

    function calculateRewards(address user) public view returns (uint256) {
        uint256 totalRewards = 0;
        Product[] memory opts = _optInProducts[user];
        for (uint256 i = 1; i < opts.length; i++) {
            if (userShares[user][products[i].productId] > 0) {
                uint256 timeWeightedRisk = block.timestamp -
                    lastOptInTime[user];
                timeWeightedRisk *= products[i].riskLevel;

                uint256 timeWeightedRewards = timeWeightedRisk *
                    products[i].premium;
                uint256 userRewards = (timeWeightedRewards *
                    userShares[user][products[i].productId]) /
                    products[i].totalCapital;
                totalRewards += userRewards;
            }
        }
        uint256 lidoRewards = (stETH.balanceOf(address(this)) * inflationRate) /
            100 /
            365;
        uint256 userBalance = stETH.balanceOf(user);
        uint256 userStakingRatio = 0;
        if (userBalance > 0) {
            userStakingRatio =
                (stETH.balanceOf(address(this)) * 1e18) /
                userBalance;
        }
        uint256 userLidoRewards = (lidoRewards * userStakingRatio) / 1e18;
        totalRewards += userLidoRewards;
        return totalRewards;
    }
}
