'use client';

import React from 'react';
import { useEffect, useState } from 'react';

interface PeerData {
  peerId: string;
  walletAddress: string;
  totalWins: number;
}

interface RoundInfo {
  currentRound: number;
  currentStage: number;
}

interface ApiResponse {
  peers: PeerData[];
  roundInfo: RoundInfo;
}

interface ErrorResponse {
  error: string;
  details?: string;
  suggestion?: string;
}

type SortColumn = 'peerId' | 'walletAddress' | 'totalWins';
type SortDirection = 'asc' | 'desc';

export default function Home() {
  const [peerData, setPeerData] = useState<PeerData[]>([]);
  const [roundInfo, setRoundInfo] = useState<RoundInfo>({ currentRound: 0, currentStage: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [errorDetails, setErrorDetails] = useState<string | null>(null);
  const [suggestion, setSuggestion] = useState<string | null>(null);
  const [useMockData, setUseMockData] = useState<boolean>(false);
  const [sortColumn, setSortColumn] = useState<SortColumn>('totalWins');
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc');

  useEffect(() => {
    const fetchPeerData = async () => {
      try {
        setLoading(true);
        setError(null);
        setErrorDetails(null);
        setSuggestion(null);

        const response = await fetch('/api/peer-wins');
        const data = await response.json();

        if (!response.ok) {
          const errorData = data as ErrorResponse;
          setError(errorData.error || 'Failed to fetch peer data');
          setErrorDetails(errorData.details || null);
          setSuggestion(errorData.suggestion || null);
          return;
        }

        const apiResponse = data as ApiResponse;
        setPeerData(apiResponse.peers);
        setRoundInfo(apiResponse.roundInfo);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'An unknown error occurred');
      } finally {
        setLoading(false);
      }
    };

    fetchPeerData();
  }, [useMockData]);

  // Function to truncate wallet address for display
  const truncateAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  // Function to handle column sorting
  const handleSort = (column: SortColumn) => {
    if (sortColumn === column) {
      // If clicking the same column, toggle direction
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      // If clicking a new column, set it as the sort column with default direction
      setSortColumn(column);
      // Default to ascending for peerId and walletAddress, descending for totalWins
      setSortDirection(column === 'totalWins' ? 'desc' : 'asc');
    }
  };

  // Function to sort the peer data based on current sort settings
  const getSortedPeerData = () => {
    return [...peerData].sort((a, b) => {
      const multiplier = sortDirection === 'asc' ? 1 : -1;

      switch (sortColumn) {
        case 'peerId':
          return multiplier * a.peerId.localeCompare(b.peerId);
        case 'walletAddress':
          return multiplier * a.walletAddress.localeCompare(b.walletAddress);
        case 'totalWins':
          return multiplier * (a.totalWins - b.totalWins);
        default:
          return 0;
      }
    });
  };

  // Get the sorted data
  const sortedPeerData = getSortedPeerData();

  // Function to render sort indicator
  const renderSortIndicator = (column: SortColumn) => {
    if (sortColumn !== column) return null;

    return (
      <span className="ml-1 inline-block">
        {sortDirection === 'asc' ? (
          <svg className="h-4 w-4 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
          </svg>
        ) : (
          <svg className="h-4 w-4 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        )}
      </span>
    );
  };

  return (
    <main className="min-h-screen p-8 bg-gradient-to-b from-gray-50 to-gray-100">
      <div className="max-w-5xl mx-auto">
        <div className="bg-white shadow-lg rounded-lg overflow-hidden mb-8 p-6 border border-gray-200">
          <h1 className="text-4xl font-bold mb-2 text-center text-blue-600">Gensyn Network Dashboard</h1>
          <p className="text-center text-gray-500 mb-6">Peer Wins and Network Status</p>

          {/* Round and Stage Information */}
          <div className="grid grid-cols-2 gap-4 mb-6">
            <div className="bg-blue-50 p-4 rounded-lg border border-blue-200 shadow-sm">
              <h2 className="text-lg font-semibold text-blue-700 mb-2">Current Round</h2>
              <div className="flex items-center">
                <span className="text-3xl font-bold text-blue-800">{roundInfo.currentRound}</span>
                <div className="ml-4 text-sm text-gray-600">
                  <p>Network consensus cycle</p>
                </div>
              </div>
            </div>

            <div className="bg-green-50 p-4 rounded-lg border border-green-200 shadow-sm">
              <h2 className="text-lg font-semibold text-green-700 mb-2">Current Stage</h2>
              <div className="flex items-center">
                <span className="text-3xl font-bold text-green-800">{roundInfo.currentStage}</span>
                <div className="ml-4 text-sm text-gray-600">
                  <p>Stage within current round</p>
                </div>
              </div>
            </div>
          </div>

          <div className="flex justify-between items-center mb-6">
            <div className="text-sm">
              {useMockData && (
                <span className="bg-yellow-100 text-yellow-800 px-3 py-1 rounded-full font-medium">
                  Using mock data
                </span>
              )}
            </div>

            <button
              onClick={() => setUseMockData(!useMockData)}
              className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded-lg text-sm transition-colors duration-200 shadow-sm"
            >
              {useMockData ? 'Use Real Data' : 'Use Mock Data'}
            </button>
          </div>

          {loading ? (
            <div className="flex justify-center items-center h-64">
              <div className="flex flex-col items-center">
                <div className="animate-spin rounded-full h-16 w-16 border-t-4 border-b-4 border-blue-600 mb-4"></div>
                <p className="text-gray-500">Loading data from blockchain...</p>
              </div>
            </div>
          ) : error ? (
            <div className="bg-red-50 border-l-4 border-red-500 text-red-700 p-5 rounded-lg shadow-md mb-6" role="alert">
              <div className="flex items-center mb-2">
                <svg className="h-6 w-6 text-red-500 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
                <h3 className="font-bold text-lg">Error Encountered</h3>
              </div>

              <p className="mb-2">{error}</p>

              {errorDetails && (
                <div className="mt-3 p-3 bg-red-100 rounded-md text-sm">
                  <strong className="block mb-1">Technical Details:</strong>
                  <code className="font-mono">{errorDetails}</code>
                </div>
              )}

              {suggestion && (
                <div className="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
                  <div className="flex items-center mb-1">
                    <svg className="h-5 w-5 text-yellow-600 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <strong className="text-yellow-700">Suggestion:</strong>
                  </div>
                  <p className="text-yellow-800">{suggestion}</p>

                  {suggestion.includes('USE_MOCK_DATA') && (
                    <button
                      onClick={() => setUseMockData(true)}
                      className="mt-2 bg-yellow-600 hover:bg-yellow-700 text-white font-medium py-1 px-3 rounded-md text-sm transition-colors duration-200"
                    >
                      Use Mock Data Instead
                    </button>
                  )}
                </div>
              )}
            </div>
          ) : (
            <div>
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-semibold text-gray-800">Peer Wins Leaderboard</h2>
                <p className="text-sm text-gray-500 italic">Click column headers to sort</p>
              </div>
              <div className="bg-white shadow-lg rounded-lg overflow-hidden border border-gray-200">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead>
                    <tr className="bg-gradient-to-r from-blue-50 to-blue-100">
                      <th
                        scope="col"
                        className="px-6 py-4 text-left text-xs font-semibold text-blue-700 uppercase tracking-wider cursor-pointer hover:bg-blue-100 transition-colors duration-150"
                        onClick={() => handleSort('peerId')}
                      >
                        <div className="flex items-center">
                          Peer ID
                          {renderSortIndicator('peerId')}
                        </div>
                      </th>
                      <th
                        scope="col"
                        className="px-6 py-4 text-left text-xs font-semibold text-blue-700 uppercase tracking-wider cursor-pointer hover:bg-blue-100 transition-colors duration-150"
                        onClick={() => handleSort('walletAddress')}
                      >
                        <div className="flex items-center">
                          Wallet Address
                          {renderSortIndicator('walletAddress')}
                        </div>
                      </th>
                      <th
                        scope="col"
                        className="px-6 py-4 text-left text-xs font-semibold text-blue-700 uppercase tracking-wider cursor-pointer hover:bg-blue-100 transition-colors duration-150"
                        onClick={() => handleSort('totalWins')}
                      >
                        <div className="flex items-center">
                          Total Wins
                          {renderSortIndicator('totalWins')}
                        </div>
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {sortedPeerData.map((peer, index) => (
                      <tr key={peer.peerId} className={`hover:bg-blue-50 transition-colors duration-150 ${index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}`}>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="flex items-center">
                            <div className="flex-shrink-0 h-8 w-8 bg-blue-100 rounded-full flex items-center justify-center">
                              <span className="text-blue-700 font-medium">{index + 1}</span>
                            </div>
                            <div className="ml-4">
                              <div className="text-sm font-medium text-gray-900 truncate max-w-xs">
                                {peer.peerId}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <a
                            href={`https://gensyn-testnet.explorer.alchemy.com/address/${peer.walletAddress}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-blue-600 hover:text-blue-800 hover:underline font-medium flex items-center"
                          >
                            <svg className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                            </svg>
                            {truncateAddress(peer.walletAddress)}
                          </a>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="flex items-center">
                            <span className="px-3 py-1 inline-flex text-sm leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                              {peer.totalWins}
                            </span>
                            {peer.totalWins > 50 && (
                              <span className="ml-2 px-2 py-1 text-xs rounded-md bg-yellow-100 text-yellow-800 font-medium">
                                High Performer
                              </span>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}

                    {sortedPeerData.length === 0 && (
                      <tr>
                        <td colSpan={3} className="px-6 py-12 text-center">
                          <div className="flex flex-col items-center">
                            <svg className="h-12 w-12 text-gray-400 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            <p className="text-gray-500 text-lg">No peer data available</p>
                            <p className="text-gray-400 text-sm mt-1">Try adding some peer IDs to your configuration</p>
                          </div>
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
