---
  title: "Insight: Node Security Issues"
author: "Ronauli Silva"
date: "06/29/2018"
output: html_notebook
---
  
  ```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
library(dplyr) #funny library name
library(ggplot2)
library(textmineR)
library(tm)
library(rvest)
library(SnowballC)
library(RColorBrewer)
library(wordcloud)

# just for fun... 


# initiating raw data

rawData <- read.csv("csv/cleaned_no_functionality.csv")
rawData$created_at <- as.Date(rawData$created_at, format="%Y-%m-%d")
rawData$disclosed_at <- as.Date(rawData$disclosed_at, format="%Y-%m-%d")
rawData$reportedAt <- strptime(rawData$reportedAt, "%Y-%m-%d %H:%M:%S")

```

## TLDR

This notebook is written in [R Markdown](http://rmarkdown.rstudio.com) Notebook. I guess the title is pretty much conveys the content :p

## How

So the idea is to see what's happening out there, see common issues, and it would be best to find it through a website that gather reports of node security issues. The best website I could find is [NodeSecurity.io](https://nodesecurity.io), and scraping the data. Thanks for Ramzi and Neel, by expanding the scraper range via connected link (github repo, hackerone report, npm keywords). 


### Data Source

1. Go to nodesecurity.io/advisories, we get:
+ Package name
+ Severity, level of damage. On range 1-10
+ Version, both vulnerable and patched one(if any)
+ Link to npm page of respective package
2. From NSP detail page, we get the hackerOne link.
3. From hackerone link, we gather these information as strings
+ Vulnerability, e.g: Interospection graphql query leaks sensitive data.
+ Impact, e.g: Execute bash script via request parameter
4. From npm page, we gather:
+ Keywords (easier to handle)
5. From Github API, we get:
+ Description/functionality of respective package

### How

So we run the scraper on node.js, and manage to find the insight using R.

## Insights

### Basic Statistic Functions

#### Average Patch Time - TODO
```{r}
basic.data <- data.frame(rawData$disclosed_at)

```


### Functionality with High Severity

```{r}
titleCorpus <- VCorpus(VectorSource(rawData$title))
clean <- function(corpus){
corpus <- tm_map(corpus, stripWhitespace)
corpus <- tm_map(corpus, removePunctuation)
corpus <- tm_map(corpus, content_transformer(tolower))
corpus <- tm_map(corpus, removeWords, stopwords("en"))
return(corpus)
}

cleanFunctionalityData <- clean(titleCorpus)
# stemming

stemFunc <- content_transformer(function(x){
paste(sapply(words(x),stemDocument),collapse = " ")
})

# stemmed functionality string
stemFnData <- tm_map(cleanFunctionalityData, stemFunc)
```

#### Bar chart: Most Frequent Word in Titles
```{r}

dtm <- TermDocumentMatrix(stemFnData)
mat <- as.matrix(dtm)

# sort by frequency and print the first 20]
sortedData <- sort(rowSums(mat), decreasing = TRUE )
first20 <- sortedData[1:20];
d <- data.frame(word = names(sortedData), freq=sortedData)
# head(d, 20)

## Find a range of y's that'll leave sufficient space above the tallest bar
bpFreqWord <- barplot(sortedData[1:20]
,main='Most Frequent Word in Titles'
,horiz=TRUE
,xlab="Occurences"
,ylab="Word"
,col=rev(brewer.pal(9, "YlOrRd"))
,las=2
,cex.names=0.8)

ggplot(data =yy  , aes(x = word, y = freq, fill=-freq)) +
geom_bar(stat="identity") +
coord_flip() +
scale_color_gradient2(low = "lightblue", high = "darkblue", midpoint=75) +
labs(title = 'Word Occurences on Reports`s Title',
x = 'Words',
y = 'Occurences') 
```

#### Title - Severity Relationships 

```{r}

df <- data.frame(rawData$title, rawData$severity)
names(df) <- c("title","severity")
df <- mutate(df, id = rownames(df))
df <- df[!(is.na(df$title) | df$title==""), ]

# create a document term matrix 
dtm <- CreateDtm(doc_vec = df$title, # character vector of documents
doc_names = df$id, # document names
ngram_window = c(1, 2), # minimum and maximum n-gram length
stopword_vec = c(tm::stopwords("english"), # stopwords from tm
tm::stopwords("SMART")), # this is the default value
lower = TRUE, # lowercase - this is the default value
remove_punctuation = TRUE, # punctuation - this is the default
remove_numbers = TRUE, # numbers - this is the default
verbose = FALSE, # Turn off status bar for this demo
cpus = 2) # default is all available cpus on the system

# construct the matrix of term counts to get the IDF vector
tf_mat <- TermDocFreq(dtm)

# TF-IDF and cosine similarity
tfidf <- t(dtm[ , tf_mat$term ]) * tf_mat$idf

tfidf <- t(tfidf)
csim <- tfidf / sqrt(rowSums(tfidf * tfidf))

csim <- csim %*% t(csim)
cdist <- as.dist(1 - csim)

hc <- hclust(cdist, method="ward.D")

clustering <- cutree(hc, 10)

plot(hc, main = "Hierarchical clustering of 100 NIH grant abstracts",
ylab = "", xlab = "", yaxt = "n")

# rect.hclust(hc, 10, border = "red") #uncomment to see the hierarchical clustering

p_words <- colSums(dtm) / sum(dtm)

cluster_words <- lapply(unique(clustering), function(x){
rows <- dtm[ clustering == x , ]

# for memory's sake, drop all words that don't appear in the cluster
rows <- rows[ , colSums(rows) > 0 ]

colSums(rows) / sum(rows) - p_words[ colnames(rows) ]
})
# create a summary table of the top 5 words defining each cluster
cluster_summary <- data.frame(cluster = unique(clustering),
size = as.numeric(table(clustering)),
top_words = sapply(cluster_words, function(d){
paste(
names(d)[ order(d, decreasing = TRUE) ][ 1:5 ], 
collapse = ", ")
}),
stringsAsFactors = FALSE)
cluster_summary
```

Wordcloud of First Cluster (xss)
```{r}

wordcloud(words = names(cluster_words[[1]]), 
freq = cluster_words[[1]],
random.order = F,
colors=brewer.pal(8, "Set2"),
main = "Top words in cluster 100")

```


#### Wordcloud - All
```{r}
dtm <- TermDocumentMatrix(stemFnData)
m = as.matrix(t(dtm))
# get word counts in decreasing order
word_freqs = sort(colSums(m), decreasing=TRUE) 
# create a data frame with words and their frequencies
dm = data.frame(word=names(word_freqs), freq=word_freqs)
dm$word
# plot wordcloud
wordcloud(dm$word, dm$freq, random.order=FALSE, colors=brewer.pal(8, "Dark2"))
```
Thank you.

