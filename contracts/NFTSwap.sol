pragma solidity 0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import './interfaces/IERC1155.sol';

contract NFTSwap is Ownable {
    event OrderCreated(uint _orderId, address _seller);
    event OrderExecuted(uint _orderId, address _buyer);

    struct Order {
        IERC1155 nftToken;
        address payable seller;
        uint128 price;
        uint32 nftId;
        uint32 value;
    }

    uint public fee; // 1% is 10
    address payable public feeReceiver;
    uint public orderId;
    mapping(uint => Order) public orders;

    constructor(uint _fee, address payable _feeReceiver) public {
        setFee(_fee, _feeReceiver);
    }


    // Before send adding order seller should call once _nftToken.setApprovalForAll(nftswap.address, true)
    function addOrder(IERC1155 _nftToken, uint32 _nftId, uint32 _value, uint128 _price) external returns (uint) {
        require(_value > 0, "NFT value can't be 0");
        require(_price > 0, "Price can't be 0");

        uint id = orderId;
        orderId++;
        orders[id] = Order({
                        nftToken: _nftToken,
                        seller: _msgSender(),
                        price: _price,
                        nftId: _nftId,
                        value: _value
                     });

        emit OrderCreated(id, _msgSender());
        return id;
    }

    function swap(uint _id) external payable {
        Order storage order = orders[_id];
        uint _fee = order.price * fee / 1000;
        require(order.value > 0, "Not valid order id provided");
        require(msg.value >= order.price + _fee, "Not enough ETH for NFT swap");

        IERC1155(order.nftToken).safeTransferFrom(order.seller, _msgSender(), order.nftId, order.value, '');
        order.value = 0;
        order.seller.transfer(order.price);

        emit OrderExecuted(_id, _msgSender());
    }


    function setFee(uint _fee, address payable _feeReceiver) public onlyOwner {
        require(_fee <= 1000, "Fee could not be more than 100%");
        require(_feeReceiver != address(0), "Zero address not allowed");

        fee = _fee;
        feeReceiver = _feeReceiver;
    }

    function collectFees() external {
        require(address(_msgSender()) == owner() || address(_msgSender()) == feeReceiver, "Only admins");
        feeReceiver.transfer(address(this).balance);
    }


}
