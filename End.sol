/**
 *Submitted for verification at Etherscan.io on 2019-11-14
*/

// hevm: flattened sources of /nix/store/8xb41r4qd0cjb63wcrxf1qmfg88p0961-dss-6fd7de0/src/end.sol
pragma solidity >=0.5.12;

contract LibNoteEnd {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  usr,
        bytes32  indexed  arg1,
        bytes32  indexed  arg2,
        bytes             data
    ) anonymous;

    modifier note {
        _;
        assembly {
            // log an 'anonymous' event with a constant 6 words of calldata
            // and four indexed topics: selector, caller, arg1 and arg2
            let mark := msize()                         // end of memory ensures zero
            mstore(0x40, add(mark, 288))              // update free memory pointer
            mstore(mark, 0x20)                        // bytes type data offset
            mstore(add(mark, 0x20), 224)              // bytes size (padded)
            calldatacopy(add(mark, 0x40), 0, 224)     // bytes payload
            log4(mark, 288,                           // calldata
                 shl(224, shr(224, calldataload(0))), // msg.sig
                 caller(),                              // msg.sender
                 calldataload(4),                     // arg1
                 calldataload(36)                     // arg2
                )
        }
    }
}

interface VatLikeEnd {
    function dai(address) external view returns (uint256);
    function ilks(bytes32 ilk) external returns (
        uint256 Art,
        uint256 rate,
        uint256 spot,
        uint256 line,
        uint256 dust
    );
    function urns(bytes32 ilk, address urn) external returns (
        uint256 ink,
        uint256 art
    );
    function debt() external returns (uint256);
    function move(address src, address dst, uint256 rad) external;
    function hope(address) external;
    function flux(bytes32 ilk, address src, address dst, uint256 rad) external;
    function grab(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external;
    function suck(address u, address v, uint256 rad) external;
    function cage() external;
}
interface CatLikeEnd {
    function ilks(bytes32) external returns (
        address flip,  // Liquidator
        uint256 chop,  // Liquidation Penalty   [ray]
        uint256 lump   // Liquidation Quantity  [rad]
    );
    function cage() external;
}
interface PotLikeEnd {
    function cage() external;
}
interface VowLikeEnd {
    function cage() external;
}
interface Flippy {
    function bids(uint id) external view returns (
        uint256 bid,
        uint256 lot,
        address guy,
        uint48  tic,
        uint48  end,
        address usr,
        address gal,
        uint256 tab
    );
    function yank(uint id) external;
}

interface PipLikeEnd {
    function read() external view returns (bytes32);
}

interface Spotty {
    function par() external view returns (uint256);
    function ilks(bytes32) external view returns (
        PipLikeEnd pip,
        uint256 mat
    );
    function cage() external;
}

contract End is LibNoteEnd {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) external note auth { wards[guy] = 1; }
    function deny(address guy) external note auth { wards[guy] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "End/not-authorized");
        _;
    }

    // --- Data ---
    VatLikeEnd  public vat;
    CatLikeEnd  public cat;
    VowLikeEnd  public vow;
    PotLikeEnd  public pot;
    Spotty   public spot;

    uint256  public live;  // cage flag
    uint256  public when;  // time of cage
    uint256  public wait;  // processing cooldown length
    uint256  public debt;  // total outstanding dai following processing [rad]

    mapping (bytes32 => uint256) public tag;  // cage price           [ray]
    mapping (bytes32 => uint256) public gap;  // collateral shortfall [wad]
    mapping (bytes32 => uint256) public Art;  // total debt per ilk   [wad]
    mapping (bytes32 => uint256) public fix;  // final cash price     [ray]

    mapping (address => uint256)                      public bag;  // [wad]
    mapping (bytes32 => mapping (address => uint256)) public out;  // [wad]

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);

    event Cage();
    event Cage(bytes32 indexed ilk);
    event Snip(bytes32 indexed ilk, uint256 indexed id, address indexed usr, uint256 tab, uint256 lot, uint256 art);
    event Skip(bytes32 indexed ilk, uint256 indexed id, address indexed usr, uint256 tab, uint256 lot, uint256 art);
    event Skim(bytes32 indexed ilk, address indexed urn, uint256 wad, uint256 art);
    event Free(bytes32 indexed ilk, address indexed usr, uint256 ink);
    event Thaw();
    event Flow(bytes32 indexed ilk);
    event Pack(address indexed usr, uint256 wad);
    event Cash(bytes32 indexed ilk, address indexed usr, uint256 wad);

    // --- Init ---
    constructor() public {
        wards[msg.sender] = 1;
        live = 1;
    }

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / RAY;
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, RAY) / y;
    }
    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, WAD) / y;
    }

    // --- Administration ---
    function file(bytes32 what, address data) external note auth {
        require(live == 1, "End/not-live");
        if (what == "vat")  vat = VatLikeEnd(data);
        else if (what == "cat")  cat = CatLikeEnd(data);
        else if (what == "vow")  vow = VowLikeEnd(data);
        else if (what == "pot")  pot = PotLikeEnd(data);
        else if (what == "spot") spot = Spotty(data);
        else revert("End/file-unrecognized-param");
        emit File(what, data);
    }
    function file(bytes32 what, uint256 data) external note auth {
        require(live == 1, "End/not-live");
        if (what == "wait") wait = data;
        else revert("End/file-unrecognized-param");
        emit File(what, data);
    }

    // --- Settlement ---
    function cage() external note auth {
        require(live == 1, "End/not-live");
        live = 0;
        when = block.timestamp;
        vat.cage();
        cat.cage();
        vow.cage();
        spot.cage();
        pot.cage();
        emit Cage();
    }

    function cage(bytes32 ilk) external note {
        require(live == 0, "End/still-live");
        require(tag[ilk] == 0, "End/tag-ilk-already-defined");
        (Art[ilk],,,,) = vat.ilks(ilk);
        (PipLikeEnd pip,) = spot.ilks(ilk);
        // par is a ray, pip returns a wad
        tag[ilk] = wdiv(spot.par(), uint(pip.read()));
        emit Cage(ilk);
    }

    function snip(bytes32 ilk, uint256 id) external {
        require(tag[ilk] != 0, "End/tag-ilk-not-defined");

        (address _clip,,,) = dog.ilks(ilk);
        ClipLike clip = ClipLike(_clip);
        (, uint256 rate,,,) = vat.ilks(ilk);
        (, uint256 tab, uint256 lot, address usr,,) = clip.sales(id);

        vat.suck(address(vow), address(vow),  tab);
        clip.yank(id);

        uint256 art = tab / rate;
        Art[ilk] = add(Art[ilk], art);
        require(int256(lot) >= 0 && int256(art) >= 0, "End/overflow");
        vat.grab(ilk, usr, address(this), address(vow), int256(lot), int256(art));
        emit Snip(ilk, id, usr, tab, lot, art);
    }

    function skip(bytes32 ilk, uint256 id) external note {
        require(tag[ilk] != 0, "End/tag-ilk-not-defined");

        (address flipV,,) = cat.ilks(ilk);
        Flippy flip = Flippy(flipV);
        (, uint rate,,,) = vat.ilks(ilk);
        (uint bid, uint lot,,,, address usr,, uint tab) = flip.bids(id);

        vat.suck(address(vow), address(vow),  tab);
        vat.suck(address(vow), address(this), bid);
        vat.hope(address(flip));
        flip.yank(id);

        uint art = tab / rate;
        Art[ilk] = add(Art[ilk], art);
        require(int(lot) >= 0 && int(art) >= 0, "End/overflow");
        vat.grab(ilk, usr, address(this), address(vow), int(lot), int(art));
        emit Skip(ilk, id, usr, tab, lot, art);
    }

    function skim(bytes32 ilk, address urn) external note {
        require(tag[ilk] != 0, "End/tag-ilk-not-defined");
        (, uint rate,,,) = vat.ilks(ilk);
        (uint ink, uint art) = vat.urns(ilk, urn);

        uint owe = rmul(rmul(art, rate), tag[ilk]);
        uint wad = min(ink, owe);
        gap[ilk] = add(gap[ilk], sub(owe, wad));

        require(wad <= 2**255 && art <= 2**255, "End/overflow");
        vat.grab(ilk, urn, address(this), address(vow), -int(wad), -int(art));
        emit Skim(ilk, urn, wad, art);
    }

    function free(bytes32 ilk) external note {
        require(live == 0, "End/still-live");
        (uint ink, uint art) = vat.urns(ilk, msg.sender);
        require(art == 0, "End/art-not-zero");
        require(ink <= 2**255, "End/overflow");
        vat.grab(ilk, msg.sender, msg.sender, address(vow), -int(ink), 0);
        emit Free(ilk, msg.sender, ink);
    }

    function thaw() external note {
        require(live == 0, "End/still-live");
        require(debt == 0, "End/debt-not-zero");
        require(vat.dai(address(vow)) == 0, "End/surplus-not-zero");
        require(block.timestamp >= add(when, wait), "End/wait-not-finished");
        debt = vat.debt();
        emit Thaw();
    }
    function flow(bytes32 ilk) external note {
        require(debt != 0, "End/debt-zero");
        require(fix[ilk] == 0, "End/fix-ilk-already-defined");

        (, uint rate,,,) = vat.ilks(ilk);
        uint256 wad = rmul(rmul(Art[ilk], rate), tag[ilk]);
        fix[ilk] = rdiv(mul(sub(wad, gap[ilk]), RAY), debt);
        emit Flow(ilk);
    }

    function pack(uint256 wad) external note {
        require(debt != 0, "End/debt-zero");
        vat.move(msg.sender, address(vow), mul(wad, RAY));
        bag[msg.sender] = add(bag[msg.sender], wad);
        emit Pack(msg.sender, wad);
    }
    function cash(bytes32 ilk, uint wad) external note {
        require(fix[ilk] != 0, "End/fix-ilk-not-defined");
        vat.flux(ilk, address(this), msg.sender, rmul(wad, fix[ilk]));
        out[ilk][msg.sender] = add(out[ilk][msg.sender], wad);
        require(out[ilk][msg.sender] <= bag[msg.sender], "End/insufficient-bag-balance");
        emit Cash(ilk, msg.sender, wad);
    }
}
