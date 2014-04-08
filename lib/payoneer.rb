require 'net/http'
require 'net/https'
require "payoneer/exception"

class Payoneer
	SANDBOX_API_URL = 'https://api.sandbox.payoneer.com/Payouts/HttpApi/API.aspx?'
	PRODUCTION_API_URL = 'https://api.payoneer.com/payouts/HttpAPI/API.aspx?'
	API_PORT = '443'


	def self.new_payee_link(partner_id, username, password, member_name)
		payoneer_api = self.new(partner_id, username, password)
		payoneer_api.payee_link(member_name)
	end

	def self.transfer_funds(partner_id, username, password, options)
		payoneer_api = self.new(partner_id, username, password)
		payoneer_api.transfer_funds(options)
	end

	def self.get_payee_report(partner_id,username,password,payee_id)
		payoneer_api = self.new(partner_id, username, password)
		payoneer_api.get_payee_report(payee_id)
	end

	def self.get_payee_details(partner_id,username,password,payee_id)
		payoneer_api = self.new(partner_id, username, password)
		payoneer_api.get_payee_details(payee_id)
	end

	def self.get_payment_status(partner_id,username,password,internal_payment_id,internal_payee_id)
		payoneer_api = self.new(partner_id, username, password)
		payoneer_api.get_payee_details(internal_payment_id,internal_payee_id)
	end

	def self.check_if_already_registered_and_active_or_get_url(partner_id, username, password)
		payoneer_api = self.new(partner_id, username, password)
		payoneer_api.check_if_already_registered_and_active_or_get_url(internal_payment_id,internal_payee_id)
	end

	def initialize(partner_id, username, password)
		@partner_id, @username, @password = partner_id, username, password
	end

	def payee_link(member_name)
		@member_name = member_name
		result = get_api_call(payee_link_args)
		#puts result.inspect
		api_result(result)
	end

	def get_payee_details(payee_id)
		@payee_id_val=payee_id
		result = get_api_call(get_payee_details_args)
	end

	def get_payee_report(payee_id)
		@payee_id_val=payee_id
		result = get_api_call(get_payee_report_args)
		returned_hash=Hash.from_xml(result)
		payoneer_payees_hash=returned_hash["payoneerpayees"]
		prepaid_or_iach_hash=payoneer_payees_hash["Prepaid"]
		Rails.logger.info prepaid_or_iach_hash
		if prepaid_or_iach_hash.nil?
			prepaid_or_iach_hash=payoneer_payees_hash["iACH"]
		end
		payee_hash=prepaid_or_iach_hash["payee"]
		payments_hash=payee_hash["Payments"]
		Rails.logger.info payments_hash
		if payments_hash
			Rails.logger.info "Inside the if condition"
			if payments_hash["Payment"].kind_of?(Array)
				loop_count=payments_hash["Payment"].count
				Rails.logger.info "Loop count"
				Rails.logger.info loop_count
				payment_date=[]
				payment_amount=[]
				payment_status=[]
				payment_description=[]
				Rails.logger.info "Inga iruken da dai! Loop munnadi"
				payments_hash["Payment"].each do |payment|
					Rails.logger.info payment["Date"]
					payment_date<<payment["Date"]
					payment_amount<<payment["Amount"]
					payment_status<<payment["Status"]
					payment_description<<payment["Description"]
				end
			else
				payment_hash=payments_hash["Payment"]
				payment_date=payment_hash["Date"]
				payment_amount=payment_hash["Amount"]
				payment_status=payment_hash["Status"]
				payment_description=payment_hash["Description"]
				total_so_far=payee_hash["TotalAmount"]
				result_hash=[loop_count,payment_date,payment_amount,payment_status,payment_description,total_so_far]
			end
			total_so_far=payee_hash["TotalAmount"]
			Rails.logger.info "Inga iruken da dai! Total Amount vangurala.. anga than"
			result_hash=[loop_count,payment_date,payment_amount,payment_status,payment_description,total_so_far]
		else
			"error"
		end
	end

	def get_payment_status(internal_payment_id,internal_payee_id)
		@internal_payment_id=internal_payment_id
		@internal_payee_id=internal_payee_id
		result =get_api_call(get_payment_status_args)
	end

	def transfer_funds(options1)
		result = get_api_call(transfer_funds_args(options1))
		if not Nokogiri::XML(result).errors.empty?
			raise PayoneerException, api_error_description(body)
		else
			Hash.from_xml(result)
		end
	end

	private

	def api_result(body)
		if is_xml? body
			raise PayoneerException, api_error_description(body)
		else
			body
		end
	end

	def is_xml?(body)
		Nokogiri::XML(body).errors.empty?
	end

	def api_error_description(body)
		body_hash = Hash.from_xml(body)
		body_hash["PayoneerResponse"]["Description"]
	end

	def get_api_call(args_hash)
		uri = URI.parse(api_url)
		#puts uri
		uri.query = URI.encode_www_form(args_hash)
		puts uri.query
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE

		request = Net::HTTP::Get.new(uri.request_uri)
		Rails.logger.info uri.to_s
		http.request(request).body
		# puts http.request(request).body
		#puts uri.request_uri
	end

	def payee_link_args
		{
			"mname" => "GetToken",
			"p1" => @username,
			"p2" => @password,
			"p3" => @partner_id,
			"p4" => @member_name
		}
	end
	def get_payment_status_args
		{
			"mname" => "GetPaymentStatus",
			"p1" => @username,
			"p2" => @password,
			"p3" => @partner_id,
			"p4" => @internal_payee_id,
			"p5" => @internal_payment_id
		}
	end
	def get_payee_details_args
		{
			"mname" => "GetPayeeDetails",
			"p1" => @username,
			"p2" => @password,
			"p3" => @partner_id,
			"p4" => @payee_id_val
		}  
	end

	def get_payee_report_args
		{
			"mname" => "GetSinglePayeeReport",
			"p1" => @username,
			"p2" => @password,
			"p3" => @partner_id,
			"p4" => @payee_id_val
		}  
	end

	def transfer_funds_args(options1)
		{
			"mname" => "PerformPayoutPayment",
			"p1" => options1[:username],
			"p2" => options1[:password],
			"p3" => options1[:partner_id],
			"p4" => options1[:program_id],
			"p5" => options1[:internal_payment_id],
			"p6" => options1[:internal_payee_id],
			"p7" => options1[:amount],
			"p8" => options1[:payment_description],
			"p9" => options1[:date]
		}
	end

	def api_url
		Rails.env.production? ? PRODUCTION_API_URL : SANDBOX_API_URL
		SANDBOX_API_URL
	end

end
