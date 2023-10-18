//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./EscrowCoin.sol";

contract EscrowMarket is Ownable(msg.sender) {
    string public name = "Escrow Contract";
    EscrowCoin public escrowCoin;  // Referencing to EscrowCoin contract   

    enum ItemState { OFFERED, AWAITING_DELIVERY, COMPLETE }
    
    // items published for sale at the escrow arrangement
    struct Item {
        uint256 price;
        string name;
        address seller;
        address buyer;        
        uint8 qty;
        bool exists;  
        ItemState state;
    }

    // balances from each buyer/seller and escrow account
    mapping (address => uint256) public escrowBalances;
    // whole stock of offered items for sale in escrow arragement
    mapping (string => Item) public stock;

    event ItemOffered(string itemName, uint256 price, uint8 quantity, address seller);
    event ItemOrdered(string itemName, address buyer);
    event ItemCompleted(string itemName, address buyer);
    
    // this takes in the address of the EscrowCoin contract
   constructor(EscrowCoin _escrowCoin) {
    escrowCoin = _escrowCoin;         
}

    // buyer funds are transfered to escrow account (in EscrowCoin contract)
    // Buyer's balance is then incremented in escrow internal balance
    // Escrow balance is incremented in escrow internal balance
    // takes in the buyer's address and amount to be credited
    
    function credit(address _buyer, uint256 _amount) public {
        require(escrowCoin.allowance(_buyer, address(this)) >= _amount, "Insufficient allowance");
        // Buyer must allow EscrowMarket contract to transfer _amount of escrowCoins to EscrowMarket account
        escrowCoin.transferFrom(_buyer, address(this), _amount); 
        escrowBalances[_buyer] += _amount;
        escrowBalances[address(this)] += _amount;
    }
    
    // this function is supposed to return the escrow balance of the buyer
    function checkEscrowBalance(address buyer) public view returns (uint256) {
        return escrowBalances[buyer];
    }
    
    // this function is supposed to return the name or the type of the stock item bought from the escrow arrangement
    function getItem(string memory _itemName) public view returns (Item memory) {
        return stock[_itemName];
    }
    
    // seller puts item for sale. 
    // Item is marked as state OFFERED
    // Item is added to escrow stock mapping
    // takes in seller address that is the message sender, name of the item, price and quantities to put for sale
    function offer(string memory _itemName, uint256 _itemPrice, uint8 _qty) public {
        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        require(_itemPrice > 0, "Price must be greater than zero");
        require(_qty > 0, "Quantity must be greater than zero");

        require(!stock[_itemName].exists, "Item already exists");
        
        Item memory item;
        item.name = _itemName;
        item.price = _itemPrice;
        item.qty = _qty;
        item.seller = msg.sender;
        item.exists = true;
        item.state = ItemState.OFFERED;
        stock[_itemName] = item;

        emit ItemOffered(_itemName, _itemPrice, _qty, msg.sender);
    }
    
    // buyer places order to buy the item listed by the seller.
    // Item is marked as state AWAITING_DELIVERY 
    // Escrow internal balance for buyer and seller is updated
    // takes in buyer address and name of the item to buy
    function order(string memory _itemName) public {
        Item storage item = stock[_itemName];
        require(item.exists, "Item does not exist");
        require(item.qty > 0, "Item is out of stock");
        require(item.state == ItemState.OFFERED, "Item is not available for purchase");
        require(escrowBalances[msg.sender] >= item.price, "Insufficient funds");

        escrowBalances[msg.sender] -= item.price;
        escrowBalances[item.seller] += item.price;
        item.buyer = msg.sender;
        item.state = ItemState.AWAITING_DELIVERY;

        emit ItemOrdered(_itemName, msg.sender);
    }
    
    // buyer confirms reception of item
    // payment is transfered from escrow EscrowCoin account to seller EscrowCoin account. 
    // Item is marked as state COMPLETE 
    // Escrow balance is decremented in escrow internal balance
    // takes in buyer address and name of the item to buy
    function complete(string memory _itemName) public {
        Item storage item = stock[_itemName];
        require(item.state == ItemState.AWAITING_DELIVERY, "Item not awaiting delivery");
        require(msg.sender == item.buyer, "Only the buyer can complete the transaction");

        escrowCoin.transfer(item.seller, item.price);
        escrowBalances[address(this)] -= item.price;
        escrowBalances[item.seller] -= item.price;
        item.state = ItemState.COMPLETE;

        emit ItemCompleted(_itemName, msg.sender);
    }
     
     // buyer did not receive item and the escrow internal balance for buyer and seller is updated
     // Item is reverted back to state OFFERED
     // takes in buyer address and name of the item to buy
     function complain (address _buyer ,string memory _itemName) public onlyOwner {         
         address seller = stock[_itemName].seller;
         stock[_itemName].buyer = address(0);
         stock[_itemName].state = ItemState.OFFERED;
         escrowBalances[_buyer] = escrowBalances[_buyer] + stock[_itemName].price;
         escrowBalances[seller] = escrowBalances[seller] - stock[_itemName].price;         
         
     }
}

