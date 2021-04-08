from requests_oauthlib import OAuth2Session
import xml.etree.ElementTree as ET
import pandas as pd
import re
import rapidjson

class YahooCon:

	redirect_uri = r'oob'
	token_url = 'https://api.login.yahoo.com/oauth2/get_token'
	token = ''	
	namespace = ''

	def __init__(self, access_token, refresh_token, client_id, client_secret, league_id):
		self.access_token = access_token
		self.refresh_token = refresh_token
		self.client_id = client_id
		self.client_secret = client_secret
		self.league_id = league_id
		self.con, self.authorization_url = self.__get_code()
		self.extra = {
		'client_id': client_id,
		'client_secret': client_secret,
		}
		
	def __set_namespace(self):
		url = 'https://fantasysports.yahooapis.com/fantasy/v2/league/nhl.l.' + self.league_id
		element = ET.fromstring(self.con.get(url).text)
		m = re.match(r'\{.*\}', element.tag)
		self.namespace = m.group(0) if m else ''

	def __get_code(self):
		authorization_base_url = 'https://api.login.yahoo.com/oauth2/request_auth'
		con = OAuth2Session(client_id = self.client_id, redirect_uri = self.redirect_uri)
		authorization_url, state = con.authorization_url(url = authorization_base_url)
		return con, authorization_url

	# Not sure if this works...
	def __refresh_token(self):
		def token_updater(token):
			self.token = token

		self = OAuth2Session(self.client_id,
			token=self.token,
			auto_refresh_kwargs=self.extra,
			auto_refresh_url=self.token_url,
			token_updater=token_updater(self.token))

	def connect_to_yahoo(self, code):
		self.token = self.con.fetch_token(token_url = self.token_url, code = code, authorization_response = self.authorization_url, client_secret = self.client_secret)
		self.__set_namespace()
		self.__refresh_token()

	def get_teams(self):
		url = 'https://fantasysports.yahooapis.com/fantasy/v2/league/nhl.l.' + self.league_id + '/teams'
		league_xml = ET.fromstring(self.con.get(url).text)
		teams = league_xml[0].find(self.namespace + 'teams')
		return pd.DataFrame([[team[2].text, team[1].text] for team in teams], columns = ('name', 'id'))

	def get_roster(self, team_id, team_name = None):
		url = 'https://fantasysports.yahooapis.com/fantasy/v2/team/nhl.l.' + self.league_id + '.t.' + team_id + '/roster/players'
		players = ET.fromstring(self.con.get(url).text)[0]
		df_list = []
		for player in players:
			player_id = player.find(self.namespace + 'player_id').text
			player_first_name = player.find(self.namespace + 'name')[1].text
			player_last_name = player.find(self.namespace + 'name')[2].text
			positions = player.find(self.namespace + 'display_position').text
			pic = player.find(self.namespace + 'headshot').text
			curr_position = player.find(self.namespace + 'selected_position').text
			df_list.append([player_id, player_first_name, player_last_name, positions, curr_position, pic])
		main = pd.DataFrame(df_list, columns = ('yahoo_id', 'first_name', 'last_name', 'eligible_positions', 'current_position', 'image'))
		if team_name is None:
			teams = self.get_teams()
			team_name = teams['name'][teams['id'] == team_id]
		team = pd.DataFrame({'team_id': [team_id]*len(df_list), 'team_name': [team_name]*len(df_list)})
		return main.join(team)

	def get_all_rostered_players(self):
		rosters = pd.DataFrame(data = None, columns = ('yahoo_id', 'first_name', 'last_name', 'eligible_positions', 'current_position', 'image', 'team_id', 'team_name'))
		teams = self.get_teams()
		for team in teams:
			rosters = rosters.append(self.get_roster(team[0], team[1]))
		rosters.index = range(rosters.shape[0])
		return rosters

	def endpoint_xml(self, endpoint):
		try:
			xml = self.con.get(endpoint).text
		except:
			xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Error>Bad_Endpoint</Error>"
		return xml
