// Complete the below questions using this array:
const array = [
  {
    username: "john",
    team: "red",
    score: 5,
    items: ["ball", "book", "pen"]
  },
  {
    username: "becky",
    team: "blue",
    score: 10,
    items: ["tape", "backpack", "pen"]
  },
  {
    username: "susy",
    team: "red",
    score: 55,
    items: ["ball", "eraser", "pen"]
  },
  {
    username: "tyson",
    team: "green",
    score: 1,
    items: ["book", "pen"]
  },

];

//Create an array using forEach that has all the usernames with a "!" to each of the usernames

let newArray = [];

array.forEach((objRef) => {
  let o_ = {username: objRef.username + '!',
            team: objRef.team,
            score: objRef.score,
            items: objRef.items.map(s => s)
          };

  newArray.push(objRef);
});

console.log(newArray);



//Create an array using map that has all the usernames with a "? to each of the usernames

let newMappArray = array.map((o) => {
  return {username: o.username + '?',
            team: o.team,
            score: o.score,
            items: o.items.map(s => s)
          };
});

console.log(newMappArray);

//Filter the array to only include users who are on team: red
let newFiltArray = array.filter(o => o.team === "red");

console.log(newFiltArray);

//Find out the total score of all users using reduce

console.log('reduce', array.reduce((accumulator, o) => { return accumulator + o.score }, 0));

// (1), what is the value of i?
0..5

// (2), Make this map function pure:
const arrayNum = [1, 2, 4, 5, 8, 9];
const newArray = arrayNum.map((num, i) => {
	console.log(num, i);
	alert(num);
	return num * 2;
})

const newArray = arrayNum.map((num, i) => num * 2);
console.log(newArray);

//BONUS: create a new list with all user information, but add "!" to the end of each items they own.
const newBonusArray = array.map((o) => {
  return {username: o.username,
            team: o.team,
            score: o.score,
            items: o.items.map(s => s + '!')
          };
});
console.log(newBonusArray);

// Clone an array
let otherArray = [1,2,3];
let cloneArray = [].concat(otherArray);
