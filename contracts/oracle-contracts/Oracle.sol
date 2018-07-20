pragma solidity ^0.4.20;

import "github.com/openzeppelin/openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract Oracle is Ownable {
    
    struct QueryInfo {
        bool isWaiting;
        address caller;
        string result;
    }
    
    uint currentId;
    address public oracle = 0x6415CB729a27e9b69891dadaFcbBCae21e5B6F9C;
    
    mapping(string => string) apiMap;
    mapping(bytes32 => QueryInfo) queryMap;

    event Query(bytes32 queryid, string url, string pubkey);
    event Result(bytes32 queryid, address caller);

    constructor() public {
        apiMap["user"] = "http://104.211.59.231/user/";
        apiMap["attestator"] = "http://104.211.59.231/attestator/";
        apiMap["livestock"] = "http://104.211.59.231/livestock/";
    }

    function __callback(bytes32 _queryid, string _result) public {
        require(queryMap[_queryid].isWaiting);
        require(msg.sender == oracle);
        queryMap[_queryid].isWaiting = false;
        queryMap[_queryid].result = _result;
        emit Result(_queryid, queryMap[_queryid].caller);
    }
    
    function api(string name) view external returns(string) {
        return apiMap[name];
    }
    
    function query(string name, string input, string pubkey) external {
        string memory url = strConcat(apiMap[name], input);
        bytes32 idHash = keccak256(currentId);
        queryMap[idHash].caller = msg.sender;
        queryMap[idHash].isWaiting = true;
        currentId++;
        emit Query(idHash, url, pubkey);
    }
    
    function result(bytes32 _queryid) view external returns(string) {
        return queryMap[_queryid].result;
    }
    
    function setAPI(string _name, string _api) external onlyOwner {
        apiMap[_name] = _api;
    }
    
    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }
    
    function strConcat(string _a, string _b) internal pure returns (string) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory abcde = new string(_ba.length + _bb.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        return string(babcde);
    }
}