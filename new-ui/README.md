# Gensyn Network Dashboard

A stylish UI that shows the total wins of peer IDs, their wallet addresses, and network status information like current round and stage, all fetched from the smart contract.

## Features

- Displays peer IDs, their wallet addresses, and total wins in a stylish leaderboard
- Supports sorting by any column (peer ID, wallet address, or total wins)
- Shows network status information including current round and stage
- Fetches data from the smart contract as a read operation
- Supports configuring peer IDs through environment variables or a text file
- Includes mock data mode for development and when rate limited
- Implements retry logic and rate limit handling
- Features a modern, responsive UI with improved error handling

## Setup

1. Install dependencies:

```bash
npm install
# or
yarn install
```

2. Configure peer IDs:

You can configure the peer IDs to track in two ways:

- **Environment Variables**: Add peer IDs as a comma-separated list in the `.env.local` file:
  ```
  PEER_IDS=peer1,peer2,peer3
  ```

- **Text File**: Add peer IDs to the `peer-ids.txt` file (one per line):
  ```
  peer1
  peer2
  peer3
  ```

3. Configure smart contract settings:

Update the `.env.local` file with the correct provider URL and contract address:

```
NEXT_PUBLIC_PROVIDER_URL=https://gensyn-testnet.g.alchemy.com/public
NEXT_PUBLIC_CONTRACT_ADDRESS=0x2fC68a233EF9E9509f034DD551FF90A79a0B8F82
NEXT_PUBLIC_ENVIRONMENT=testnet

# Set to 'true' to use mock data instead of making blockchain calls
# This is useful when you're being rate limited by the provider
USE_MOCK_DATA=true
```

## Running the Application

Run the development server:

```bash
npm run dev
# or
yarn dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser to see the dashboard.

## API Endpoints

- `GET /api/peer-wins`: Returns peer IDs, wallet addresses, and total wins

## Handling Rate Limits

The application may encounter rate limits when making requests to the blockchain provider. To handle this:

1. **Mock Data Mode**: Enable mock data mode by setting `USE_MOCK_DATA=true` in your `.env.local` file or by clicking the "Use Mock Data" button in the UI.

2. **Retry Logic**: The application includes retry logic with exponential backoff to handle temporary failures.

3. **Sequential Requests**: When fetching data for multiple peer IDs, requests are made sequentially with delays to avoid hitting rate limits.

## Building for Production

```bash
npm run build
# or
yarn build
```

Then start the production server:

```bash
npm run start
# or
yarn start
```
