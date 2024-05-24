// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract Wallet {
    event CreateTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event AddActionToTransaction(
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event VoteTransaction(address indexed owner, uint256 indexed txIndex);
    event UnvoteTransaction(address indexed owner, uint256 indexed txIndex);
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numVotedRequired;

    struct Action {
        address to;
        uint256 value;
        bytes data;
    }

    struct Transaction {
        Action[] actions;
        bool submitted;
        bool executed;
        uint256 numVoted;
        address owner;
    }

    // mapping from tx index => owner => bool
    mapping(uint256 => mapping(address => bool)) public isVoted;

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notSubmitted(uint256 _txIndex) {
        require(!transactions[_txIndex].submitted, "tx already executed");
        _;
    }

    modifier onlySubmitted(uint256 _txIndex) {
        require(transactions[_txIndex].submitted, "tx already executed");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notVoted(uint256 _txIndex) {
        require(!isVoted[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _numVotedRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _numVotedRequired > 0 && _numVotedRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numVotedRequired = _numVotedRequired;
    }

    // create transaction with one action
    function createTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactions.length;

        Transaction storage _transaction = transactions.push();
        _transaction.actions.push(
            Action({to: _to, value: _value, data: _data})
        );
        _transaction.submitted = false;
        _transaction.executed = false;
        _transaction.numVoted = 1;
        _transaction.owner = msg.sender;
        isVoted[txIndex][msg.sender] = true;

        emit CreateTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    // add action to specific transaction
    function addActionToTransaction(
        uint _txIndex,
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(msg.sender == transaction.owner, "not transaction owner");

        transaction.actions.push(Action({to: _to, value: _value, data: _data}));

        emit AddActionToTransaction(_txIndex, _to, _value, _data);
    }

    // submit transaction after adding all actions so that owners can vote
    function submitTransaction(
        uint256 _txIndex
    ) public onlyOwner txExists(_txIndex) notSubmitted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.submitted = true;

        emit SubmitTransaction(msg.sender, _txIndex);
    }

    // vote transaction
    function voteTransaction(
        uint256 _txIndex
    )
        public
        onlyOwner
        txExists(_txIndex)
        onlySubmitted(_txIndex)
        notExecuted(_txIndex)
        notVoted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numVoted += 1;
        isVoted[_txIndex][msg.sender] = true;

        emit VoteTransaction(msg.sender, _txIndex);
    }

    // execute transaction
    function executeTransaction(
        uint256 _txIndex
    )
        public
        onlyOwner
        txExists(_txIndex)
        onlySubmitted(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.numVoted >= numVotedRequired, "cannot execute tx");

        transaction.executed = true;

        for (uint i = 0; i < transaction.actions.length; i++) {
            (bool success, ) = transaction.actions[i].to.call{
                value: transaction.actions[i].value
            }(transaction.actions[i].data);
            require(success, "tx failed");
        }

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    // cancel the vote about the transaction
    function unvoteTransaction(
        uint256 _txIndex
    )
        public
        onlyOwner
        txExists(_txIndex)
        onlySubmitted(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isVoted[_txIndex][msg.sender], "tx not confirmed");

        transaction.numVoted -= 1;
        isVoted[_txIndex][msg.sender] = false;

        emit UnvoteTransaction(msg.sender, _txIndex);
    }

    // get list of owners
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    // get transaction count
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    // get specific transaction information
    function getTransaction(
        uint256 _txIndex
    )
        public
        view
        returns (
            uint256 numActions,
            bool submitted,
            bool executed,
            uint256 numVoted
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.actions.length,
            transaction.submitted,
            transaction.executed,
            transaction.numVoted
        );
    }

    // get specific action information
    function getAction(
        uint256 _txIndex,
        uint256 _actionIndex
    ) public view returns (address to, uint256 value, bytes memory data) {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.actions[_actionIndex].to,
            transaction.actions[_actionIndex].value,
            transaction.actions[_actionIndex].data
        );
    }
}
