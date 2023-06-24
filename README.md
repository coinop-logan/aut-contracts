# Voting contract exercise

This contains the Voting contract as per the exercise specs. For expediency I have forked the Aut-Labs/contracts repo, added [the voting contract](contracts/voting/Voting.sol) and removed the existing tests and added [my own set of tests](test/voting.test.js).

As in the original repo, the tests are run on a local node via hardhat.

# Setup

Basically the same as the original repo:

1. Create .env file and put your testing private key there
    ```
    PRIVATE_KEY='your_private_key'
    ```

2. Install dependencies
`npm install`

3. Compile the smart contracts 
`npm run compile`

4. In a separate terminal
`npx hardhat node`

5. Run tests
`npm run test`