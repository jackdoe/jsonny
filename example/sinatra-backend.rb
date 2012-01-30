require 'rubygems'
require 'sinatra'
require 'json'
get '/' do
	rows = lambda do
			ret = []
			t = ['UITableViewCellStyleValue1','UITableViewCellStyleValue2','UITableViewCellStyleSubtitle',''].shuffle.first	
			randomColor = lambda do {:red => rand(255).to_s,:green => rand(255).to_s, :blue => rand(255).to_s, :alpha => '1'} end
			rand(500).times do
			 	ret << {
					'initWithStyle' => t,
					'backgroundColor' => randomColor.call,					
					'image' => { 	'url' => 'https://www.google.com/intl/en_com/images/srpr/logo3w.png', 
							'layer' => { 	'maskToBounds' => 'YES',
									'cornerRadius' => rand(90).to_s,
									'borderWidth' => rand(20).to_s,
									'borderColor' => randomColor.call,										
							}
						    },
					'textLabel' => { 
							'text' => "more detailed object #{t}", 
							'font' => { 
									'name' => ['Trebuchet MS','AmericanTypewriter-Light','Arial'].shuffle.first, 
									'size' => (50 - rand(40)).to_s 
								  },
							'textColor' => randomColor.call
							},
					'detailTextLabel' => "very simple text inside",
					'heightForRow' => rand(300).to_s,
					'editingStyleDelete' => 'http://127.0.0.1:9393/delete/5',
					'didSelectRow' => { 	
								'name' => 'JSonny', 
								'init' => { 
										'method' => 'initWithString:', 
										'argument' => @request.url.gsub(/(\?)?UITableViewStyleGrouped/,'').gsub(/$/,"#{rand(5) > 2 ? '?UITableViewStyleGrouped' : ''}")
									  }
							  }
				}
			end
			return ret			
		end
	return {'title' => 'simple table', 'sections' => [rows.call,rows.call]}.to_json	
end