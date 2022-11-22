const { expect } = require("chai");

describe("Marketplace", function () {
    // deploy contract
    async function deploy() {
        const Marketplace = await hre.ethers.getContractFactory("Marketplace");
        const marketplace = await Marketplace.deploy();
        await marketplace.deployed();
        return {marketplace};
    }

    let marketplace;
    
    this.beforeAll(async function(){
        const contracts = await deploy();
        marketplace = contracts.marketplace;
    } , 10000);


    it("Set recipient" , async function(){
        const [account1 , account2] = await ethers.getSigners();
        await marketplace.setRecipient(account2.address);
        expect(account2.address).to.equal(await marketplace.recipient().then((ret)=>{return ret}));
    });



});


