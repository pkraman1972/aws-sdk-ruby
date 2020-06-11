require_relative '../../spec_helper'

module Aws
  module Log
    describe ParamFilter do
      let(:service) { 'Peccy Service' }
      let(:hash_filter) { { service => [:password] } }
      let(:array_filter) { [:password] }

      describe '#initialize' do
        it 'accepts a filter as a hash' do
          filter = ParamFilter.new(filter: hash_filter)
          filters = filter.instance_variable_get(:@filters)
          expect(filters).to include(hash_filter)
        end

        it 'adds filters to existing sensitive params' do
          filter = ParamFilter.new(filter: { 'STS' => [:new_param] })
          filters = filter.instance_variable_get(:@filters)
          expect(filters['STS']).to include(:new_param)
          expect(filters['STS']).to include(*ParamFilter::SENSITIVE['STS'])
        end

        it 'supports a filter as an array (legacy)' do
          filter = ParamFilter.new(filter: array_filter)
          filters = filter.instance_variable_get(:@filters)
          expect(filters.values).to all(include(*array_filter))
        end
      end

      describe '#filter' do
        subject { ParamFilter.new(filter: hash_filter) }

        context 'with an array' do
          it 'filters parameter names' do
            filtered = subject.filter([{ password: 'p@assw0rd' }], service)
            expect(filtered).to eq([{ password: '[FILTERED]' }])
          end
        end

        context 'with a Struct' do
          it 'filters parameter names' do
            instance = Struct.new(:password).new('p@assw0rd')
            filtered = subject.filter(instance, service)
            expect(filtered).to eq(password: '[FILTERED]')
          end
        end

        context 'with a hash' do
          it 'filters parameter names' do
            filtered = subject.filter({password: 'p@ssw0rd'}, service)
            expect(filtered).to eq(password: '[FILTERED]')
          end
        end

        context 'with no service' do
          it 'filters parameter names from all services' do
            filtered = subject.filter({password: 'p@ssw0rd', private_key: 'private'})
            expect(filtered).to eq(password: '[FILTERED]', private_key: '[FILTERED]')
          end
        end
      end
    end
  end
end
