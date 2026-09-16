#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <stdexcept>

namespace cassotis {
using Bytes = std::vector<uint8_t>;
struct Writer {
    Bytes data;
    void u8(uint8_t v) { data.push_back(v); }
    void u16(uint16_t v);
    void u32(uint32_t v);
    void u64(uint64_t v);
    void string(const std::string &v);
    void schema(uint16_t version = 1) { u16(version); u16(0); }
};
struct Reader {
    const Bytes &data;
    size_t offset = 0;
    explicit Reader(const Bytes &v) : data(v) {}
    uint8_t u8();
    uint16_t u16();
    uint32_t u32();
    uint64_t u64();
    std::string string();
    uint16_t schema();
    void end();
};
struct Candidate {
    std::string text, comment;
    uint8_t source = 0, kind = 0;
    bool deletable = false;
};
struct PreeditWarning { uint32_t start = 0, length = 0; uint8_t kind = 0; };
struct Result {
    bool handled = false, pending = false;
    int32_t selected = -1, page = 0, pages = 0;
    std::string commit, preedit, query, completion;
    std::vector<Candidate> candidates;
    std::vector<PreeditWarning> warnings;
};
struct Key {
    uint16_t special = 0;
    uint32_t modifiers = 0, scan = 0;
    bool release = false, repeat = false;
    uint64_t timestamp = 0;
    std::string text;
};
struct Shortcut { uint16_t key = 0; uint8_t modifiers = 0; bool disabled = false; };
struct State {
    uint8_t mode = 0, dictionary = 0, scheme = 0, flags = 2;
    uint32_t fuzzy = 0;
    uint8_t pageKeys = 0, completionKey = 0, pageSize = 5;
    Shortcut shortcuts[5];
};
Bytes encodeKey(const Key &key);
Result decodeResult(const Bytes &data);
Bytes encodeState(const State &state);
State decodeState(const Bytes &data);

// One connection owns one context. A timed-out transaction closes the socket:
// no reply from that engine generation can be applied to a later client.
class EngineClient {
    int fd_ = -1;
    uint64_t request_ = 0, generation_ = 0;
    Bytes transact(uint16_t type, const Bytes &payload, int timeoutMs = 1000);
public:
    ~EngineClient() { disconnect(); }
    EngineClient() = default;
    EngineClient(const EngineClient &) = delete;
    EngineClient &operator=(const EngineClient &) = delete;
    bool connect(const std::string &path);
    bool connected() const { return fd_ >= 0; }
    void disconnect();
    void active(bool value);
    void reset();
    void surrounding(const std::string &text, int32_t cursor);
    Result key(const Key &value);
    Result poll();
    Result removeCandidate(int32_t index, const std::string &query, const Candidate &expected);
    State state();
    void setState(const State &state);
    void clearLearning();
};
}
