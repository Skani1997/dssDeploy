/**
 *Submitted for verification at Etherscan.io on 2019-11-14
*/
pragma solidity >=0.5.12;

interface GemLikeJoin {
    function decimals() external view returns (uint);
    function transfer(address,uint) external returns (bool);
    function transferFrom(address,address,uint) external returns (bool);
}

interface DSTokenLikeJoin {
    function mint(address,uint) external;
    function burn(address,uint) external;
}

interface VatLikeJoin {
    function slip(bytes32,address,int) external;
    function move(address,address,uint) external;
}

contract GemJoin{
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth { wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "GemJoin/not-authorized");
        _;
    }

    VatLikeJoin public vat;
    bytes32 public ilk;
    GemLikeJoin public gem;
    uint    public dec;
    uint    public live;  // Access Flag

    constructor(address vat_, bytes32 ilk_, address gem_) public {
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLikeJoin(vat_);
        ilk = ilk_;
        gem = GemLikeJoin(gem_);
        dec = gem.decimals();
    }
    function cage() external auth {
        live = 0;
    }
    function join(address usr, uint wad) external {
        require(live == 1, "GemJoin/not-live");
        require(int(wad) >= 0, "GemJoin/overflow");
        vat.slip(ilk, usr, int(wad));
        require(gem.transferFrom(msg.sender, address(this), wad), "GemJoin/failed-transfer");
    }
    function exit(address usr, uint wad) external {
        require(wad <= 2 ** 255, "GemJoin/overflow");
        vat.slip(ilk, msg.sender, -int(wad));
        require(gem.transfer(usr, wad), "GemJoin/failed-transfer");
    }
}

contract ETHJoin{
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth { wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "ETHJoin/not-authorized");
        _;
    }

    VatLikeJoin public vat;
    bytes32 public ilk;
    uint    public live;  // Access Flag

    constructor(address vat_, bytes32 ilk_) public {
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLikeJoin(vat_);
        ilk = ilk_;
    }
    function cage() external auth {
        live = 0;
    }
    function join(address usr) external payable {
        require(live == 1, "ETHJoin/not-live");
        require(int(msg.value) >= 0, "ETHJoin/overflow");
        vat.slip(ilk, usr, int(msg.value));
    }
    function exit(address payable usr, uint wad) external {
        require(int(wad) >= 0, "ETHJoin/overflow");
        vat.slip(ilk, msg.sender, -int(wad));
        usr.transfer(wad);
    }
}

contract DaiJoin{
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth { wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "DaiJoin/not-authorized");
        _;
    }

    VatLikeJoin public vat;
    DSTokenLikeJoin public dai;
    uint    public live;  // Access Flag

    constructor(address vat_, address dai_) public {
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLikeJoin(vat_);
        dai = DSTokenLikeJoin(dai_);
    }
    function cage() external auth {
        live = 0;
    }
    uint constant ONE = 10 ** 27;
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function join(address usr, uint wad) external {
        vat.move(address(this), usr, mul(ONE, wad));
        dai.burn(msg.sender, wad);
    }
    function exit(address usr, uint wad) external {
        require(live == 1, "DaiJoin/not-live");
        vat.move(msg.sender, address(this), mul(ONE, wad));
        dai.mint(usr, wad);
    }
}
