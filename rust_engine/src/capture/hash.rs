use blake3;

/// First frame seed (genesis state)
pub const GENESIS_HASH: [u8; 32] = [0u8; 32];

/// Chain hash: frame + previous hash
pub fn compute_chain_hash(frame_bytes: &[u8], prev_hash: &[u8; 32]) -> [u8; 32] {
    let mut hasher = blake3::Hasher::new();

    hasher.update(frame_bytes);
    hasher.update(prev_hash);

    *hasher.finalize().as_bytes()
}