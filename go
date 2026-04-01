package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type Message struct {
	Text string `json:"text"`
}

var collection *mongo.Collection

func main() {
	client, err := mongo.Connect(context.TODO(), options.Client().ApplyURI("mongodb://mongo:27017"))
	if err != nil {
		log.Fatal(err)
	}

	collection = client.Database("testdb").Collection("messages")

	http.HandleFunc("/add", addMessage)
	http.HandleFunc("/get", getMessages)

	log.Println("Backend running on :8080")
	http.ListenAndServe(":8080", nil)
}

func addMessage(w http.ResponseWriter, r *http.Request) {
	var msg Message
	json.NewDecoder(r.Body).Decode(&msg)

	collection.InsertOne(context.TODO(), msg)
	w.Write([]byte("Added"))
}

func getMessages(w http.ResponseWriter, r *http.Request) {
	cursor, _ := collection.Find(context.TODO(), map[string]interface{}{})

	var results []Message
	cursor.All(context.TODO(), &results)

	json.NewEncoder(w).Encode(results)
}