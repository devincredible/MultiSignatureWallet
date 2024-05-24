// test case

// test if any user can create transaction or not
// test if the owner only can execute the transaction after enough voting
// test if the owner can execute after enough voting and if it fails with wrong call data

const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Wallet Test", function () {
  let owner;

  async function deployWalletFixture() {
    [owner, addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();

    const Wallet = await ethers.getContractFactory("Wallet");
    wallet = await Wallet.deploy([addr1, addr2, addr3], 2);

    return { wallet, owner, addr1, addr2, addr3, addr4, addr5 };
  }

  it("only the owner can create transaction", async () => {
    const { wallet, owner, addr1, addr2, addr3, addr4, addr5 } =
      await loadFixture(deployWalletFixture);

    // Check if the caller is owner
    await expect(
      wallet
        .connect(addr4)
        .createTransaction(addr1, 1, new TextEncoder().encode("hello"))
    ).to.be.revertedWith("not owner");
  });

  it("only can execute transaction after enough vote", async () => {
    const { wallet, owner, addr1, addr2, addr3, addr4, addr5 } =
      await loadFixture(deployWalletFixture);

    // Check if the caller is owner
    await wallet
      .connect(addr1)
      .createTransaction(addr4, 1, new TextEncoder().encode("hello"));
    await wallet.connect(addr1).submitTransaction(0);
    await wallet.connect(addr1).voteTransaction(0);
    await expect(
      wallet.connect(addr1).executeTransaction(0)
    ).to.be.revertedWith("cannot execute tx");
  });

  it("execute after enough vote and fail from wrong calldata", async () => {
    const { wallet, owner, addr1, addr2, addr3, addr4, addr5 } =
      await loadFixture(deployWalletFixture);

    // Check if the caller is owner
    await wallet
      .connect(addr1)
      .createTransaction(addr4, 1, new TextEncoder().encode("hello"));
    await wallet.connect(addr1).submitTransaction(0);
    await wallet.connect(addr1).voteTransaction(0);
    await wallet.connect(addr2).voteTransaction(0);
    await expect(
      wallet.connect(addr1).executeTransaction(0)
    ).to.be.revertedWith("tx failed");
  });
});
