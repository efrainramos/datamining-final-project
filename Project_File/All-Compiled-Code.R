################################################################################
## Libraries ------
library(spotifyr)
library(genius)
library(tm)
library(wordcloud)
library(wordcloud2)
library(tidyr)
library(lexicon)
library(tidytext)
library(tidyverse)
library(dplyr)
library(XML)
library(gridExtra)
library(ggplot2)


################################################################################
## Spotify authorizations to import data. -----

# Authorize Spotify API info
Sys.setenv(SPOTIFY_CLIENT_ID = '3d49f13ca5124a8280e741a3f3842ff7')
Sys.setenv(SPOTIFY_CLIENT_SECRET = '6aaabaa303b548ee97f1b286a68933c9')
access_token <- get_spotify_access_token()


################################################################################
## Getting playlists from Spotify.  -----

# Get playlist categories
cats <- get_categories()


# Hiphop category
hiphop <- get_category_playlists("hiphop")

RapCaviar <- get_playlist("37i9dQZF1DX0XUsuxWHRQd")
MostNecessary <- get_playlist("37i9dQZF1DX2RxBh64BHjQ")
SignedXOXO <- get_playlist("37i9dQZF1DX2A29LI7xHn1")


# Pop category
pop <- get_category_playlists("pop")

TodaysTopHits <- get_playlist("37i9dQZF1DXcBWIGoYBM5M")
PopRising <- get_playlist("37i9dQZF1DWUa8ZRTfalHk")


# Rock category
rock <- get_category_playlists("rock")

RockThis <- get_playlist("37i9dQZF1DXcF6B6QPhFDv")
AltNOW <- get_playlist("37i9dQZF1DWVqJMsgEN0F4")
RockHard <- get_playlist("37i9dQZF1DWWJOmJ7nRx0C")


# Metal category
metal <- get_category_playlists("metal")

KickassMetal <- get_playlist("37i9dQZF1DWTcqUzwhNmKv")
NewCore <- get_playlist("37i9dQZF1DWXIcbzpLauPS")
NuMetalGeneration <- get_playlist("37i9dQZF1DXcfZ6moR6J0G")


# Indie category
indie <- get_category_playlists("indie_alt")

Alternative10s <- get_playlist("37i9dQZF1DX873GaRGUmPl")
EarlyAlternative <- get_playlist("37i9dQZF1DXdTCdwCKzXwo")
Alternative00s <- get_playlist("37i9dQZF1DX0YKekzl0blG")



################################################################################
## Spotify playlist to dataframe function. -----

playlist_to_df <- function(playlist){
  
  #creates df of Track Names and Pop Score
  outputDF <- data.frame(playlist[["tracks"]][["items"]][["track.name"]],playlist[["tracks"]][["items"]][["track.popularity"]])
  colnames(outputDF)<-c("name","popularity")
  outputDF$name <-gsub("\\s*\\([^\\)]+\\)","",as.character(outputDF$name))
  #removes all parenthesis and everything inside them
  
  #artist name added to df
  vector1 <- character(nrow(outputDF))
  for(i in 1:nrow(outputDF)){
    vector1[i]<- playlist[["tracks"]][["items"]][["track.artists"]][[i]][["name"]][[1]]
  }
  outputDF$artist <- vector1
  
  #lyric time
  outputDF$lyrics <-NA
  
  #error handling to keep on adding to df if lyrics cannot be found
  for(i in 1:nrow(outputDF)){
    try({
      lyrics_from_genius <- genius_lyrics(artist = outputDF$artist[i],song = outputDF$name[i], info = "simple")
      lyric_list <- lyrics_from_genius$lyric
      outputDF$lyrics[i] <- paste(unlist(lyric_list),collapse=' ')
      
    })
    
    
    #Adds additional track audio features to our data frame. key, energy, loudness, mode etc...
    playID <- playlist[["id"]]
    features_df <- get_playlist_audio_features("spotify",playID)
    
    try({
      outputDF$danceability <- NA
      outputDF$danceability <- features_df$danceability
      outputDF$key <- features_df$key
      outputDF$energy <- features_df$energy
      outputDF$loudness <- features_df$loudness
      outputDF$mode <- features_df$mode
      outputDF$speechiness <- features_df$speechiness
      outputDF$acousticness <- features_df$acousticness
      outputDF$instrumentalness <- features_df$instrumentalness
      outputDF$liveness <- features_df$liveness
      outputDF$valence <- features_df$valence
      outputDF$tempo <- features_df$tempo
    })
  }
  return(outputDF)
}

# Function Testing
RapCaviar_df <- playlist_to_df(RapCaviar)
View(RapCaviar_df)



################################################################################
## For loop to turn every playlist to dataframe.  -----

playlistsNames <- list(RapCaviar, MostNecessary, SignedXOXO, TodaysTopHits,
                       PopRising, RockThis, AltNOW, RockHard, KickassMetal,
                       NewCore, NuMetalGeneration, Alternative10s, EarlyAlternative,
                       Alternative00s)

# Warning: this loop takes ~30min with 16gb of RAM.
list <- list()

for (i in 1:length(playlistsNames)) {
  
  list[[i]] <- playlist_to_df(playlistsNames[[i]])
  
}

View(list)

################################################################################
## Function to clean dataframe lyrics of punctuation, capitalization, etc.  -----

MrClean <- function(list){
  
  list_avgs <- lapply(list, function(x) lapply(x, mean, na.rm=TRUE))
  
  print(list_avgs)
  str(list_avgs)
  
  for (i in 1:length(list)) {
    
    print(i)
    
    # Set the text to lowercase
    list[[i]]$lyrics <- tolower(list[[i]]$lyrics)
    
    # Remove mentions, urls, emojis, numbers, punctuations, etc.
    list[[i]]$lyrics <- gsub("@\\w+", "", list[[i]]$lyrics)
    list[[i]]$lyrics <- gsub("https?://.+", "", list[[i]]$lyrics)
    list[[i]]$lyrics <- gsub("\\d+\\w*\\d*", "", list[[i]]$lyrics)
    list[[i]]$lyrics <- gsub("#\\w+", "", list[[i]]$lyrics)
    list[[i]]$lyrics <- gsub("[^\x01-\x7F]", "", list[[i]]$lyrics)
    list[[i]]$lyrics <- gsub("[[:punct:]]", "", list[[i]]$lyrics)
    
    
    # Remove spaces and newlines
    list[[i]]$lyrics <- gsub("\n", " ", list[[i]]$lyrics)
    list[[i]]$lyrics <- gsub("^\\s+", "", list[[i]]$lyrics)
    list[[i]]$lyrics <- gsub("\\s+$", "", list[[i]]$lyrics)
    list[[i]]$lyrics <- gsub("[ |\t]+", " ", list[[i]]$lyrics)
    
    
    #Replace NA with mean
    list[[i]]$popularity <- replace_na(list[[i]]$popularity, as.integer(list_avgs[[i]]$popularity))
    list[[i]]$danceability <- replace_na(list[[i]]$danceability, list_avgs[[i]]$danceability)
    list[[i]]$key <- replace_na(list[[i]]$key, as.integer(list_avgs[[i]]$key))
    list[[i]]$energy <- replace_na(list[[i]]$energy, list_avgs[[i]]$energy)
    list[[i]]$loudness <- replace_na(list[[i]]$loudness, list_avgs[[i]]$loudness)
    list[[i]]$mode <- replace_na(list[[i]]$mode, as.integer(list_avgs[[i]]$mode))
    list[[i]]$speechiness <- replace_na(list[[i]]$speechiness, list_avgs[[i]]$speechiness)
    list[[i]]$acousticness <- replace_na(list[[i]]$acousticness, list_avgs[[i]]$acousticness)
    list[[i]]$instrumentalness <- replace_na(list[[i]]$instrumentalness, list_avgs[[i]]$instrumentalness)
    list[[i]]$liveness  <- replace_na(list[[i]]$liveness, list_avgs[[i]]$liveness)
    list[[i]]$valence <- replace_na(list[[i]]$valence, list_avgs[[i]]$valence)
    list[[i]]$tempo <- replace_na(list[[i]]$tempo, list_avgs[[i]]$tempo)
  }
  
  return(list)
  
}

clean_list <- MrClean(list)

################################################################################
## Function to tokenize lyrics.  -----

MrClean_Token <- function(list){
  
  token1 <- list %>% 
    select(lyrics) %>%
    unnest_tokens("word", "lyrics") %>%
    anti_join(get_stopwords())
  
}



################################################################################
## Function to conduct sentiment analysis given playlist.  -----

get_sentiment_data <- function(clean_list){
  
  token <- MrClean_Token(clean_list)
  
  token <- token %>%
    anti_join(get_stopwords(), by = "word")
  
  nrc_sent <- token %>%
    select(word) %>%
    inner_join(get_sentiments("nrc")) %>%
    count(word, sentiment) %>%
    arrange(desc(n))
  
  return(nrc_sent)
  
}

playlist_sentiment <- get_sentiment_data(clean_list[[1]])

ggplot(playlist_sentiment, aes(x=sentiment, y=n)) +
  geom_col()



################################################################################
## Sentiment Visualizations. -----

#Hiphop - Setting up to combine playlists into genre
df1 <- clean_list[[1]]
df2 <- clean_list[[2]]
df3 <- clean_list[[3]]

#Pop - Setting up to combine playlists into genre
df4 <- clean_list[[4]]
df5 <- clean_list[[5]]

#Rock - Setting up to combine playlists into genre
df6 <- clean_list[[6]]
df7 <- clean_list[[7]]
df8 <- clean_list[[8]]

#Metal - Setting up to combine playlists into genre
df9 <- clean_list[[9]]
df10 <- clean_list[[10]]
df11 <- clean_list[[11]]

#Indie - Setting up to combine playlists into genre
df12 <- clean_list[[12]]
df13 <- clean_list[[13]]
df14 <- clean_list[[14]]


#Genres to choose from
Pop_s <- rbind(df4, df5)
Rock_s <- rbind(df6, df7, df8)
Hiphop_s <- rbind(df1, df2, df3)
Indie_s <- rbind(df12, df13, df14)
Metal_s <- rbind(df9, df10, df11)

#Bar plot function - emotions
bar_chart <- function(genre, title){
  
  playlist1_sentiment <- get_sentiment_data(genre)
  
  playlist1_sentiment_c <- subset(playlist1_sentiment, sentiment != "negative" & sentiment !="positive")
  
  ggplot(playlist1_sentiment_c, aes(x=sentiment, y=n, fill=sentiment)) +
    geom_col()+
    ggtitle(title)+
    xlab("Sentiment")+
    ylab("Count")+
    guides(fill = guide_legend(title = "Sentiment \nAnalysis"))+
    theme(plot.title =element_text(hjust = 0.5, vjust = 1 ,face = "bold", size = 25),
          axis.title.x = element_text( size = 16, vjust = -.75),  axis.title.y = element_text( size = 16)
          ,legend.title = element_text(size = 12, face = "bold"), axis.text.x = element_blank())
}

#Bar plot function - positive vs negative
bar_chart_p <- function(genre, title){
  
  playlist1_sentiment <- get_sentiment_data(genre)
  
  playlist1_sentiment_c <- subset(playlist1_sentiment, sentiment == "negative"| sentiment =="positive")
  
  ggplot(playlist1_sentiment_c, aes(x=sentiment, y=n, fill=sentiment)) +
    geom_col()+
    ggtitle(title)+
    xlab("Polarity")+
    ylab("Count")+
    theme(plot.title =element_text(hjust = 0.5, vjust = 1 ,face = "bold", size = 25),
          axis.title.x = element_text( size = 16),  axis.title.y = element_text( size = 16),
          legend.position = "none")
}

#Word cloud function
word_cloud <- function(genre){
  
  get_dat <- get_sentiment_data(genre)
  
  get_dat$sentiment <- NULL
  
  get_dat <- distinct(get_dat)
  
  names(get_dat)[2] <- "freq"
  
  cloud <- wordcloud2(get_dat)
  
  return(cloud)
}



# Testing of functions
word_cloud(Indie_s)
word_cloud(Hiphop_s)
word_cloud(Pop_s)
word_cloud(Metal_s)
word_cloud(Rock_s)

Indie_sent <- bar_chart(Indie_s, "Indie")
Indie_sent
Indie_pol <- bar_chart_p(Indie_s, "Indie")
Indie_pol

Hiphop_sent <- bar_chart(Hiphop_s, "Hiphop")
Hiphop_sent
Hiphop_pol <- bar_chart_p(Hiphop_s, "Hiphop")
Hiphop_pol

Pop_sent <- bar_chart(Pop_s, "Pop")
Pop_sent
Pop_pol <- bar_chart_p(Pop_s, "Pop")
Pop_pol

Metal_sent <- bar_chart(Metal_s, "Metal")
Metal_sent
Metal_pol <- bar_chart_p(Metal_s, "Metal")
Metal_pol

Rock_sent <- bar_chart(Rock_s, "Rock")
Rock_sent

Rock_pol <- bar_chart_p(Rock_s, "Rock")
Rock_pol


grid.arrange(Indie_sent,Hiphop_sent, Pop_sent,Metal_sent,Rock_sent, nrow = 2 )

??grid.arrange(Indie_pol,Hiphop_pol, Pop_pol,Metal_pol,Rock_pol, nrow = 2 )



################################################################################


save.image(file = "rdata_file.Rdata")

write.csv(list4, file="list4")
