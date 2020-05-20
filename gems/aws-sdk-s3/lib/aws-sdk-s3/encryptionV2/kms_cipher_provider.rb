require 'base64'

module Aws
  module S3
    module EncryptionV2
      # @api private
      class KmsCipherProvider

        def initialize(options = {})
          @kms_key_id = options[:kms_key_id]
          @kms_client = options[:kms_client]
        end

        # @return [Array<Hash,Cipher>] Creates and returns a new encryption
        #   envelope and encryption cipher.
        def encryption_cipher
          cek_alg = 'AES/GCM/NoPadding'
          encryption_context = {
            'kms_cmk_id' => @kms_key_id,
            'aws:x-amz-cek-alg' => cek_alg
          }
          key_data = @kms_client.generate_data_key(
            key_id: @kms_key_id,
            encryption_context: encryption_context,
            key_spec: 'AES_256',
          )
          cipher = Utils.aes_encryption_cipher(:GCM)
          cipher.key = key_data.plaintext
          cipher.auth_data = ''
          envelope = {
            'x-amz-key-v2' => encode64(key_data.ciphertext_blob),
            'x-amz-iv' => encode64(cipher.iv = cipher.random_iv),
            'x-amz-cek-alg' => cek_alg,
            'x-amz-tag-len' => 16 * 8,
            'x-amz-wrap-alg' => 'kms+context',
            'x-amz-matdesc' => Json.dump(encryption_context)
          }
          [envelope, cipher]
        end

        # @return [Cipher] Given an encryption envelope, returns a
        #   decryption cipher.
        def decryption_cipher(envelope)
          encryption_context = Json.load(envelope['x-amz-matdesc'])
          key = @kms_client.decrypt(
            ciphertext_blob: decode64(envelope['x-amz-key-v2']),
            encryption_context: encryption_context
          ).plaintext
          cek_alg = envelope['x-amz-wrap-alg'] == 'kms+context' ?
            encryption_context['aws:x-amz-cek-alg'] : envelope['x-amz-cek-alg']
          iv = decode64(envelope['x-amz-iv'])
          block_mode =
            case cek_alg
            when 'AES/CBC/PKCS5Padding'
              :CBC
            when 'AES/CBC/PKCS7Padding'
              :CBC
            when 'AES/GCM/NoPadding'
              :GCM
            else
              type = envelope['x-amz-cek-alg'].inspect
              msg = "unsupported content encrypting key (cek) format: #{type}"
              raise Errors::DecryptionError, msg
            end
          Utils.aes_decryption_cipher(block_mode, key, iv)
        end

        private

        def encode64(str)
          Base64.encode64(str).split("\n") * ""
        end

        def decode64(str)
          Base64.decode64(str)
        end

      end
    end
  end
end
