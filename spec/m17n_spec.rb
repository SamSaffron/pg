#!/usr/bin/env spec
# encoding: utf-8

require 'rubygems'
require 'spec'
require 'spec/lib/helpers'

$LOAD_PATH.unshift('ext')
require 'pg'

describe "multinationalization support" do
	include PgTestingHelpers

	RUBY_VERSION_VEC = RUBY_VERSION.split('.').map {|c| c.to_i }.pack("N*")
	MIN_RUBY_VERSION_VEC = [1,9,1].pack('N*')


	before( :all ) do
		@conn = nil
		if RUBY_VERSION_VEC >= MIN_RUBY_VERSION_VEC
			before( :all ) do
				@conn = setup_testing_db( "m17n" )
			end
			@conn.exec( 'BEGIN' )
		end
	end

	before( :each ) do
		pending "depends on m17n support in Ruby >= 1.9.1" if @conn.nil?
	end


	it "should return the same bytes in text format that are sent as inline text" do
		binary_file = File.join(Dir.pwd, 'spec/data', 'random_binary_data')
		in_bytes = File.open(binary_file, 'r:ASCII-8BIT').read

		out_bytes = nil
		@conn.transaction do |conn|
			conn.exec("SET standard_conforming_strings=on")
			res = conn.exec("VALUES ('#{PGconn.escape_bytea(in_bytes)}'::bytea)", [], 0)
			out_bytes = PGconn.unescape_bytea(res[0]['column1'])
		end
		out_bytes.should== in_bytes
	end

	describe "rubyforge #22925: m17n support" do
		it "should return results in the same encoding as the client (iso-8859-1)" do
			out_string = nil
			@conn.transaction do |conn|
				conn.internal_encoding = 'iso8859-1'
				res = conn.exec("VALUES ('fantasia')", [], 0)
				out_string = res[0]['column1']
			end
			out_string.should == 'fantasia'
			out_string.encoding.should == Encoding::ISO8859_1
		end

		it "should return results in the same encoding as the client (utf-8)" do
			out_string = nil
			@conn.transaction do |conn|
				conn.internal_encoding = 'utf-8'
				res = conn.exec("VALUES ('世界線航跡蔵')", [], 0)
				out_string = res[0]['column1']
			end
			out_string.should == '世界線航跡蔵'
			out_string.encoding.should == Encoding::UTF_8
		end

		it "should return results in the same encoding as the client (EUC-JP)" do
			out_string = nil
			@conn.transaction do |conn|
				conn.internal_encoding = 'EUC-JP'
				stmt = "VALUES ('世界線航跡蔵')".encode('EUC-JP')
				res = conn.exec(stmt, [], 0)
				out_string = res[0]['column1']
			end
			out_string.should == '世界線航跡蔵'.encode('EUC-JP')
			out_string.encoding.should == Encoding::EUC_JP
		end

		it "the connection should return ASCII-8BIT when the server encoding is SQL_ASCII" do
			@conn.external_encoding.should == Encoding::ASCII_8BIT
		end

		it "works around the unsupported JOHAB encoding by returning stuff in 'ASCII_8BIT'" do
			pending "figuring out how to create a string in the JOHAB encoding" do
				out_string = nil
				@conn.transaction do |conn|
					conn.exec( "set client_encoding = 'JOHAB';" )
					stmt = "VALUES ('foo')".encode('JOHAB')
					res = conn.exec( stmt, [], 0 )
					out_string = res[0]['column1']
				end
				out_string.should == 'foo'.encode(Encoding::ASCII_8BIT)
				out_string.encoding.should == Encoding::ASCII_8BIT
			end
		end

		it "should use client encoding for escaped string" do
			original = "string to escape".force_encoding("euc-jp")
			@conn.set_client_encoding("euc_jp")
			escaped  = @conn.escape(original)
			escaped.encoding.should == Encoding::EUC_JP
		end

	end


	after( :each ) do
		@conn.exec( 'ROLLBACK' ) if @conn
	end

	after( :all ) do
		teardown_testing_db( @conn ) if @conn
	end
end
