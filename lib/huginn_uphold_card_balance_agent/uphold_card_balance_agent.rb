module Agents
  class UpholdCardBalanceAgent < Agent
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The Uphold Card Balance agent fetches balances for all cards in Uphold.

      `changes_only` is only used to emit event about a card's change.

      `whithout_conversion_diff` prevents event's creation because of  value (USD/EUR) in real time in for card's value.

      `debug` is used to verbose mode.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "CreatedByApplicationId": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          "address": {
            "wire": "xxxxxxxx"
          },
          "available": "0.00",
          "balance": "0.00",
          "currency": "XXX",
          "id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          "label": "Xxxx Xxxxxxxx",
          "lastTransactionAt": null,
          "settings": {
            "position": 1,
            "protected": false,
            "starred": true
          },
          "createdByApplicationClientId": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          "normalized": [
            {
              "available": "0.00",
              "balance": "0.00",
              "currency": "XXX"
            }
          ],
          "wire": [
            {
              "accountName": "Xxxxxxxxxx",
              "address": {
                "line1": "Xxxxx Xxxxxx",
                "line2": "XXXXXXXXXXXXXXXX"
              },
              "bic": "XXXXXXXX",
              "currency": "XXX",
              "iban": "XXXXXXXXXXXXXXXXXXXX",
              "name": "xxxxxxxxxx"
            },
            {
              "accountName": "XXXXXXXXXXX",
              "accountNumber": "xxxxxxxxxxxx",
              "address": {
                "line1": "xxxxxxxxxxxxxxxx",
                "line2": "xxxxxxxxxxxxxxxx"
              },
              "bic": "XXXXXXXX",
              "currency": "XXX",
              "name": "Xxxxxxx",
              "routingNumber": "xXXxxxxxx"
            }
          ]
        }
    MD

    def default_options
      {
        'bearer_token' => '',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true',
        'debug' => 'false',
        'whithout_conversion_diff' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :bearer_token, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :whithout_conversion_diff, type: :boolean
    form_configurable :debug, type: :boolean

    def validate_options
      unless options['bearer_token'].present?
        errors.add(:base, "bearer_token is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('whithout_conversion_diff') && boolify(options['whithout_conversion_diff']).nil?
        errors.add(:base, "if provided, whithout_conversion_diff must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      handle interpolated[:bearer_token]
    end

    private

    def handle(bearer_token)
##########################################
# I know it's bad bad bad bad!!! but impossible for me to fetch a fucking json with ruby.. issue with encoding. ASCII-8BIT
##########################################
#      uri = URI.parse("https://api.uphold.com/v0/me/cards")
#      request = Net::HTTP::Get.new(uri)
#      request["Authorization"] = "Bearer #{bearer_token}"
#      request['Content-Type'] = 'application/json'
#
#      
#      req_options = {
#        use_ssl: uri.scheme == "https",
#      }
#      
#      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
#        http.request(request)
#      end
#
#      log response.code
#      log response
#


      payload = `curl -s --header "Authorization: Bearer #{bearer_token}" https://api.uphold.com/v0/me/cards`
      payload = JSON.parse(payload)
      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload.each do |card|
              create_event payload: card
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,")
            last_status = JSON.parse(last_status)
            payload.each do |card|
              found = false
              last_status.each do |cardbis|
                if card == cardbis
                  found = true
                  if interpolated['debug'] == 'true'
                    log "found is #{found}"
                  end
                end
                if interpolated['whithout_conversion_diff'] == 'true' and card['CreatedByApplicationId'] == cardbis['CreatedByApplicationId'] and card['balance'] == cardbis['balance']
                  found = true
                  if interpolated['debug'] == 'true'
                    log "found is #{found} #{card['balance']} = #{cardbis['balance']} #{card['CreatedByApplicationId']} #{cardbis['CreatedByApplicationId']}"
                  end
                end
              end
              if interpolated['debug'] == 'true'
                log "found is #{found}"
              end
              if found == false
                create_event payload: card
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
