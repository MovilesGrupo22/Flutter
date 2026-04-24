import 'dart:collection';

// LRU (Least Recently Used) cache: when capacity is exceeded, the entry that
// was accessed least recently is evicted to make room for the new one.
//
// Why LinkedHashMap: it preserves insertion order, so the first entry is always
// the oldest (least recently used). On a cache hit we remove and re-insert the
// entry to move it to the "most recent" end — O(1) with a hash map.
//
// Eviction: when put() causes the map to exceed maxSize, we evict the first
// key (the LRU entry). This keeps memory bounded at maxSize items.
class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _map = LinkedHashMap();

  LruCache({required this.maxSize});

  // Returns the cached value for [key], promoting it to most-recently-used.
  // Returns null if the key is not present.
  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    final value = _map.remove(key) as V;
    _map[key] = value; // re-insert at tail = most recent
    return value;
  }

  // Inserts [key] → [value]. If the key already exists it is refreshed.
  // When inserting causes size to exceed [maxSize], the LRU entry is evicted.
  void put(K key, V value) {
    _map.remove(key); // remove to re-insert at tail regardless
    _map[key] = value;
    if (_map.length > maxSize) {
      _map.remove(_map.keys.first); // evict least recently used
    }
  }

  void remove(K key) => _map.remove(key);

  void clear() => _map.clear();

  int get size => _map.length;

  Iterable<K> get keys => _map.keys;
}
