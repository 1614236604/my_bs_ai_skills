# Object Pool Patterns (MAC TTI Thread)

## Grant Pool Pattern (NrMacGrantPool<T>)

```cpp
template<class T>
class NrMacGrantPool {
    std::vector<T> m_pool;           // Pre-allocated in init()
    NrMacList<int> m_freeList;       // Free index list (DLINK)
    std::vector<bool> m_isAllocated; // Bitmap for dedup
public:
    void init(int poolSize) {
        m_pool.resize(poolSize);       // One-time allocation
        m_isAllocated.resize(poolSize, false);
        for (int i = 0; i < poolSize; i++)
            m_freeList.pushBack(i);
    }
    T* allocate() {
        if (m_freeList.empty()) return NULL;
        int idx = m_freeList.popFront();
        m_isAllocated[idx] = true;
        return &m_pool[idx];
    }
    void release(T* obj) {
        int idx = obj - &m_pool[0];
        m_isAllocated[idx] = false;
        m_freeList.pushBack(idx);
    }
};
```

## DLINK Free List Pattern (MacRlcMsgQ)

```cpp
// Pre-allocated message queue with DLINK free list
class MacRlcMsgQ {
    MacRlcMsg m_msgPool[MAX_MSG_NUM];  // Fixed-size pool
    DLINK m_freeList;                   // Free message list
    DLINK m_pendingList;                // Pending message list
    pthread_mutex_t m_mutex;            // Thread safety
public:
    void init() {
        for (int i = 0; i < MAX_MSG_NUM; i++)
            DLINK_INSERT_TAIL(&m_freeList, &m_msgPool[i].link);
    }
    MacRlcMsg* allocMsg() {
        pthread_mutex_lock(&m_mutex);
        MacRlcMsg* msg = DLINK_REMOVE_HEAD(&m_freeList);
        pthread_mutex_unlock(&m_mutex);
        return msg;
    }
    void freeMsg(MacRlcMsg* msg) {
        pthread_mutex_lock(&m_mutex);
        DLINK_INSERT_TAIL(&m_freeList, &msg->link);
        pthread_mutex_unlock(&m_mutex);
    }
};
```

## TTI-Bucketed Storage Pattern

```cpp
// For data indexed by TTI (slot), use circular buffer
class TtiBucketedStore {
    Entry m_buckets[MAX_TTI_WINDOW];  // Fixed circular buffer
    int m_windowSize;
public:
    Entry* getBucket(int tti) {
        return &m_buckets[tti % m_windowSize];
    }
};
```

## Key Rules

1. All `std::vector` must be `resize()`d in `init()` — never `push_back()` in TTI path
2. Use `NrMacList<int>` (DLINK-based) for free lists — O(1) alloc/release
3. Use `std::vector<bool>` bitmap for dedup — pre-sized in `init()`
4. Use fixed-size C arrays for small bounded collections
5. Use `DLINK` macros for intrusive linked lists (zero allocation)
