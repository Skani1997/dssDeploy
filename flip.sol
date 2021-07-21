/**
 *Submitted for verification at Etherscan.io on 2019-11-14
*/

// hevm: flattened sources of /nix/store/8xb41r4qd0cjb63wcrxf1qmfg88p0961-dss-6fd7de0/src/flip.sol
pragma solidity >=0.5.12;

interface VatLikeFlip {
    function move(address,address,uint) external;
    function flux(bytes32,address,address,uint) external;
}

interface CatLikeFlip {
    function claw(uint256) external;
}

contract Flipper{
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth { wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Flipper/not-authorized");
        _;
    }

    // --- Data ---
    struct Bid {
        uint256 bid;
        uint256 lot;
        address guy;  // high bidder
        uint48  tic;  // expiry time
        uint48  end;
        address usr;
        address gal;
        uint256 tab;
    }

    mapping (uint => Bid) public bids;

    VatLikeFlip public   vat;
    bytes32 public   ilk;

    uint256 constant ONE = 1.00E18;
    uint256 public   beg = 1.05E18;  // 5% minimum bid increase
    uint48  public   ttl = 3 hours;  // 3 hours bid duration
    uint48  public   tau = 2 days;   // 2 days total auction length
    uint256 public kicks = 0;
    CatLikeFlip public   cat;            // cat liquidation module

    // --- Events ---
    event Kick(
      uint256 id,
      uint256 lot,
      uint256 bid,
      uint256 tab,
      address indexed usr,
      address indexed gal
    );

    // --- Init ---
    constructor(address vat_,  address cat_,bytes32 ilk_) public {
        vat = VatLikeFlip(vat_);
        cat = CatLikeFlip(cat_);
        ilk = ilk_;
        wards[msg.sender] = 1;
    }

    // --- Math ---
    function add(uint48 x, uint48 y) internal pure returns (uint48 z) {
        require((z = x + y) >= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // --- Admin ---
    function file(bytes32 what, uint data) external auth {
        if (what == "beg") beg = data;
        else if (what == "ttl") ttl = uint48(data);
        else if (what == "tau") tau = uint48(data);
        else revert("Flipper/file-unrecognized-param");
    }
    function file(bytes32 what, address data) external auth {
        if (what == "cat") cat = CatLikeFlip(data);
        else revert("Flipper/file-unrecognized-param");
    }
    
    // --- Auction ---
    function kick(address usr, address gal, uint tab, uint lot, uint bid)
        public auth returns (uint id)
    {
        require(kicks < uint(2**256 - 1), "Flipper/overflow");
        id = ++kicks;

        bids[id].bid = bid;
        bids[id].lot = lot;
        bids[id].guy = msg.sender; // configurable??
        bids[id].end = add(uint48(block.timestamp), tau);
        bids[id].usr = usr;
        bids[id].gal = gal;
        bids[id].tab = tab;

        vat.flux(ilk, msg.sender, address(this), lot);

        emit Kick(id, lot, bid, tab, usr, gal);
    }
    function tick(uint id) external {
        require(bids[id].end < block.timestamp, "Flipper/not-finished");
        require(bids[id].tic == 0, "Flipper/bid-already-placed");
        bids[id].end = add(uint48(block.timestamp), tau);
    }
    function tend(uint id, uint lot, uint bid) external {
        require(bids[id].guy != address(0), "Flipper/guy-not-set");
        require(bids[id].tic > block.timestamp || bids[id].tic == 0, "Flipper/already-finished-tic");
        require(bids[id].end > block.timestamp, "Flipper/already-finished-end");

        require(lot == bids[id].lot, "Flipper/lot-not-matching");
        require(bid <= bids[id].tab, "Flipper/higher-than-tab");
        require(bid >  bids[id].bid, "Flipper/bid-not-higher");
        require(mul(bid, ONE) >= mul(beg, bids[id].bid) || bid == bids[id].tab, "Flipper/insufficient-increase");

        if (msg.sender != bids[id].guy) {
            vat.move(msg.sender, bids[id].guy, bids[id].bid);
            bids[id].guy = msg.sender;
        }
        vat.move(msg.sender, bids[id].gal, bid - bids[id].bid);

        bids[id].bid = bid;
        bids[id].tic = add(uint48(now), ttl);
    }
    function dent(uint id, uint lot, uint bid) external {
        require(bids[id].guy != address(0), "Flipper/guy-not-set");
        require(bids[id].tic > block.timestamp || bids[id].tic == 0, "Flipper/already-finished-tic");
        require(bids[id].end > block.timestamp, "Flipper/already-finished-end");

        require(bid == bids[id].bid, "Flipper/not-matching-bid");
        require(bid == bids[id].tab, "Flipper/tend-not-finished");
        require(lot < bids[id].lot, "Flipper/lot-not-lower");
        require(mul(beg, lot) <= mul(bids[id].lot, ONE), "Flipper/insufficient-decrease");

        if (msg.sender != bids[id].guy) {
            vat.move(msg.sender, bids[id].guy, bid);
            bids[id].guy = msg.sender;
        }
        vat.flux(ilk, address(this), bids[id].usr, bids[id].lot - lot);

        bids[id].lot = lot;
        bids[id].tic = add(uint48(now), ttl);
    }
    function deal(uint id) external {
        require(bids[id].tic != 0 && (bids[id].tic < block.timestamp || bids[id].end < block.timestamp), "Flipper/not-finished");
        cat.claw(bids[id].tab);
        vat.flux(ilk, address(this), bids[id].guy, bids[id].lot);
        delete bids[id];
    }

    function yank(uint id) external auth {
        require(bids[id].guy != address(0), "Flipper/guy-not-set");
        require(bids[id].bid < bids[id].tab, "Flipper/already-dent-phase");
        cat.claw(bids[id].tab);
        vat.flux(ilk, address(this), msg.sender, bids[id].lot);
        vat.move(msg.sender, bids[id].guy, bids[id].bid);
        delete bids[id];
    }
}
