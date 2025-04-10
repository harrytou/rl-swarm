import fs from 'fs';
import path from 'path';

/**
 * Reads peer IDs from a text file
 * @param filePath Path to the text file containing peer IDs (one per line)
 * @returns Array of peer IDs
 */
export function readPeerIdsFromFile(filePath: string): string[] {
  try {
    // Read the file
    const fileContent = fs.readFileSync(filePath, 'utf-8');

    // Split by newline and filter out empty lines
    return fileContent
        .split('\n')
        .map(line => line.trim())
        .filter(line => line.length > 0);
  } catch (error) {
    console.error(`Error reading peer IDs from file: ${error}`);
    return [];
  }
}

/**
 * Gets peer IDs from environment variables or a text file
 * @returns Array of peer IDs
 */
export function getPeerIds(): string[] {
  // If not available in env vars, try to read from the text file
  const filePath = path.join(process.cwd(), 'peer-ids.txt');
  return readPeerIdsFromFile(filePath);
}
