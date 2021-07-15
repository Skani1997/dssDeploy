/**
 *Submitted for verification at Etherscan.io on 2019-11-14
*/
pragma solidity >=0.4.23;

contract DSNotePause {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  guy,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
        uint256           wad,
        bytes             fax
    ) anonymous;

    modifier note {
        bytes32 foo;
        bytes32 bar;
        uint256 wad;

        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
            wad := callvalue()
        }

        emit LogNote(msg.sig, msg.sender, foo, bar, wad, msg.data);

        _;
    }
}


interface DSAuthorityPause {
    function canCall(
        address src, address dst, bytes4 sig
    ) external view returns (bool);
}

contract DSAuthEventsPause {
    event LogSetAuthority (address indexed authority);
    event LogSetOwner     (address indexed owner);
}

contract DSAuthPause is DSAuthEventsPause {
    DSAuthority  public  authority;
    address      public  owner;

    constructor() public {
        owner = msg.sender;
        emit LogSetOwner(msg.sender);
    }

    function setOwner(address owner_)
        public
        auth
    {
        owner = owner_;
        emit LogSetOwner(owner);
    }

    function setAuthority(DSAuthority authority_)
        public
        auth
    {
        authority = authority_;
        emit LogSetAuthority(address(authority));
    }

    modifier auth {
        require(isAuthorized(msg.sender, msg.sig), "ds-auth-unauthorized");
        _;
    }

    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority == DSAuthority(address(0))) {
            return false;
        } else {
            return authority.canCall(src, address(this), sig);
        }
    }
}

contract DSPause is DSAuthPause, DSNotePause {

    // --- admin ---

    modifier wait { require(msg.sender == address(proxy), "ds-pause-undelayed-call"); _; }

    function setDelay(uint delay_) public note wait {
        delay = delay_;
    }

    // --- math ---

    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x, "ds-pause-addition-overflow");
    }

    // --- data ---

    mapping (bytes32 => bool) public plans;
    DSPauseProxy public proxy;
    uint         public delay;

    // --- init ---

    constructor(uint delay_, address owner_, DSAuthority authority_) public {
        delay = delay_;
        owner = owner_;
        authority = authority_;
        proxy = new DSPauseProxy();
    }

    // --- util ---

    function hash(address usr, bytes32 tag, bytes memory fax, uint eta)
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(usr, tag, fax, eta));
    }

    function soul(address usr)
        internal view
        returns (bytes32 tag)
    {
        assembly { tag := extcodehash(usr) }
    }

    // --- operations ---

    function plot(address usr, bytes32 tag, bytes memory fax, uint eta)
        public note auth
    {
        require(eta >= add(block.timestamp, delay), "ds-pause-delay-not-respected");
        plans[hash(usr, tag, fax, eta)] = true;
    }

    function drop(address usr, bytes32 tag, bytes memory fax, uint eta)
        public note auth
    {
        plans[hash(usr, tag, fax, eta)] = false;
    }

    function exec(address usr, bytes32 tag, bytes memory fax, uint eta)
        public note
        returns (bytes memory out)
    {
        require(plans[hash(usr, tag, fax, eta)], "ds-pause-unplotted-plan");
        require(soul(usr) == tag,                "ds-pause-wrong-codehash");
        require(block.timestamp >= eta,                      "ds-pause-premature-exec");

        plans[hash(usr, tag, fax, eta)] = false;

        out = proxy.exec(usr, fax);
        require(proxy.owner() == address(this), "ds-pause-illegal-storage-change");
    }
}

// plans are executed in an isolated storage context to protect the pause from
// malicious storage modification during plan execution
contract DSPauseProxy {
    address public owner;
    modifier auth { require(msg.sender == owner, "ds-pause-proxy-unauthorized"); _; }
    constructor() public { owner = msg.sender; }

    function exec(address usr, bytes memory fax)
        public auth
        returns (bytes memory out)
    {
        bool ok;
        (ok, out) = usr.delegatecall(fax);
        require(ok, "ds-pause-delegatecall-error");
    }
}
