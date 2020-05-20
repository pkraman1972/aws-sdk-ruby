require 'openssl'

module Aws
  module S3
    module EncryptionV2
      # @api private
      module Utils

        UNSAFE_MSG = "unsafe encryption, data is longer than key length"

        class << self

          def encrypt(key, data)
            case key
            when OpenSSL::PKey::RSA # asymmetric encryption
              warn(UNSAFE_MSG) if key.public_key.n.num_bits < cipher_size(data)
              key.public_encrypt(data)
            when String # symmetric encryption
              warn(UNSAFE_MSG) if cipher_size(key) < cipher_size(data)
              cipher = aes_encryption_cipher(:ECB, key)
              cipher.update(data) + cipher.final
            end
          end

          def encrypt_aes_gcm(key, data, auth_data)
            warn(UNSAFE_MSG) if cipher_size(key) < cipher_size(data)
            cipher = aes_encryption_cipher(:GCM, key)
            cipher.iv = (iv = cipher.random_iv)
            cipher.auth_data = auth_data

            iv + cipher.update(data) + cipher.final + cipher.auth_tag
          end

          def decrypt(key, data)
            begin
              case key
              when OpenSSL::PKey::RSA # asymmetric decryption
                key.private_decrypt(data)
              when String # symmetric Decryption
                cipher = aes_cipher(:decrypt, :ECB, key, nil)
                cipher.update(data) + cipher.final
              end
            rescue OpenSSL::Cipher::CipherError
              msg = 'decryption failed, possible incorrect key'
              raise Errors::DecryptionError, msg
            end
          end

          def decrypt_aes_gcm(key, data, auth_data)
            # data is iv (12B) + key + tag (16B)
            buf = data.unpack('C*')
            iv = buf[0,12].pack('C*') # iv will always be 12 bytes
            tag = buf[-16, 16].pack('C*') # tag is 16 bytes
            enc_key = buf[12, buf.size - (12+16)].pack('C*')
            cipher = aes_cipher(:decrypt, :GCM, key, iv)
            cipher.auth_tag = tag
            cipher.auth_data = auth_data
            cipher.update(enc_key) + cipher.final
          end

          # @param [String] block_mode "CBC" or "ECB"
          # @param [OpenSSL::PKey::RSA, String, nil] key
          # @param [String, nil] iv The initialization vector
          def aes_encryption_cipher(block_mode, key = nil, iv = nil)
            aes_cipher(:encrypt, block_mode, key, iv)
          end

          # @param [String] block_mode "CBC" or "ECB"
          # @param [OpenSSL::PKey::RSA, String, nil] key
          # @param [String, nil] iv The initialization vector
          def aes_decryption_cipher(block_mode, key = nil, iv = nil)
            aes_cipher(:decrypt, block_mode, key, iv)
          end

          # @param [String] mode "encrypt" or "decrypt"
          # @param [String] block_mode "CBC" or "ECB"
          # @param [OpenSSL::PKey::RSA, String, nil] key
          # @param [String, nil] iv The initialization vector
          def aes_cipher(mode, block_mode, key, iv)
            cipher = key ?
              OpenSSL::Cipher.new("aes-#{cipher_size(key)}-#{block_mode.downcase}") :
              OpenSSL::Cipher.new("aes-256-#{block_mode.downcase}")
            cipher.send(mode) # encrypt or decrypt
            cipher.key = key if key
            cipher.iv = iv if iv
            puts "Created an AES cipher: #{cipher.name}"
            cipher
          end

          # @param [String] key
          # @return [Integer]
          # @raise ArgumentError
          def cipher_size(key)
            key.bytesize * 8
          end

        end
      end
    end
  end
end
