import { NextResponse } from 'next/server';
import { createPublicClient, http } from 'viem';
import { getPeerIds } from '@/lib/peerUtils';
import { sleep } from '@/lib/utils';
import {gensynTestnet} from "@account-kit/infra";

// Load environment variables
const providerUrl = process.env.NEXT_PUBLIC_PROVIDER_URL!;
const contractAddress = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS! as `0x${string}`;
const useMockData = process.env.USE_MOCK_DATA === 'true';
const maxRetries = 3;
const retryDelay = 1000; // 1 second

// Create a public client to interact with the blockchain
const client = createPublicClient({
  chain: gensynTestnet,
  transport: http(providerUrl),
});

// Helper function to retry a function with exponential backoff
async function withRetry<T>(fn: () => Promise<T>, retries = maxRetries, delay = retryDelay): Promise<T> {
  try {
    return await fn();
  } catch (error) {
    if (retries <= 0) throw error;

    console.log(`Request failed, retrying in ${delay}ms... (${retries} retries left)`);
    await sleep(delay);
    return withRetry(fn, retries - 1, delay * 2);
  }
}

// Mock data for development
function getMockData(peerIds: string[]) {
  return {
    peers: peerIds.map(peerId => ({
      peerId,
      walletAddress: `0x${Array(40).fill(0).map(() => Math.floor(Math.random() * 16).toString(16)).join('')}`,
      totalWins: Math.floor(Math.random() * 100),
    })),
    roundInfo: {
      currentRound: Math.floor(Math.random() * 10),
      currentStage: Math.floor(Math.random() * 4)
    }
  };
}

// Function to fetch data from the blockchain
async function fetchBlockchainData(peerIds: string[]) {
  // Fetch EOAs for all peer IDs - with retry logic
  const eoas = await withRetry(() => client.readContract({
    address: contractAddress,
    abi: [
      {
        inputs: [{ type: 'string[]' }],
        name: 'getEoa',
        outputs: [{ type: 'address[]' }],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'getEoa',
    args: [peerIds],
  }));

  // Fetch total wins for each peer ID - one at a time to avoid rate limiting
  const wins = [];
  for (const peerId of peerIds) {
    // Add a small delay between requests to avoid rate limiting
    await sleep(300);

    const win = await withRetry(() => client.readContract({
      address: contractAddress,
      abi: [
        {
          inputs: [{ type: 'string' }],
          name: 'getTotalWins',
          outputs: [{ type: 'uint256' }],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      functionName: 'getTotalWins',
      args: [peerId],
    }));

    wins.push(win);
  }

  // Fetch current round and stage
  const [currentRound, currentStage] = await Promise.all([
    withRetry(() => client.readContract({
      address: contractAddress,
      abi: [
        {
          inputs: [],
          name: 'currentRound',
          outputs: [{ type: 'uint256' }],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      functionName: 'currentRound',
    })),
    withRetry(() => client.readContract({
      address: contractAddress,
      abi: [
        {
          inputs: [],
          name: 'currentStage',
          outputs: [{ type: 'uint256' }],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      functionName: 'currentStage',
    }))
  ]);

  // Combine the data
  return {
    peers: peerIds.map((peerId, index) => ({
      peerId,
      walletAddress: eoas[index],
      totalWins: Number(wins[index]),
    })),
    roundInfo: {
      currentRound: Number(currentRound),
      currentStage: Number(currentStage)
    }
  };
}

export async function GET() {
  try {
    // Get peer IDs from environment variables or text file
    const peerIds = getPeerIds();

    if (peerIds.length === 0) {
      return NextResponse.json(
        { error: 'No peer IDs found' },
        { status: 404 }
      );
    }

    // Use mock data if enabled, otherwise fetch from blockchain
    const peerData = useMockData
      ? getMockData(peerIds)
      : await fetchBlockchainData(peerIds);

    return NextResponse.json(peerData);
  } catch (error) {
    console.error('Error fetching peer data:', error);

    // Provide more detailed error information
    const errorMessage = error instanceof Error
      ? error.message
      : 'Unknown error';

    return NextResponse.json(
      {
        error: 'Failed to fetch peer data',
        details: errorMessage,
        // If we're rate limited, suggest using mock data
        suggestion: errorMessage.includes('rate limit')
          ? 'You are being rate limited. Try setting USE_MOCK_DATA=true in your .env.local file.'
          : undefined
      },
      { status: 500 }
    );
  }
}
