# Example: rely entirely on Hiera for all parameter values (recommended).
include ollama

# Example: override specific parameters at the class declaration level,
# bypassing Hiera for those keys.
#
# class { 'ollama':
#   manage_service         => true,
#   enable_external_access => true,
#   models                 => [
#     { 'name' => 'qwen3.5:4b'     },
#     { 'name' => 'qwen3.5:9b'     },
#     { 'name' => 'qwen3.5:latest' },
#   ],
# }
