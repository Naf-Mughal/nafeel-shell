#pragma once

// nafeel: the parts of Noctalia's config/config_types.h its clipboard and
// storage-key code needs (the rest is Noctalia's own settings).

#include <cstdint>

enum class StorageKeySource : std::uint8_t {
  SecretService = 0,
  File = 1,
};
