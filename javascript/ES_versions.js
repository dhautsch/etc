//
// ES7 introduced includes and ** operator
//
const dragons = ['Tim', 'Johnathan', 'Sandy', 'Sarah'];
console.log(dragons.includes('John'));

// #2) Check if this array includes any name that has "John" inside of it. If it does, return that
// name or names in an array.
const dragons = ['Tim', 'Johnathan', 'Sandy', 'Sarah'];

console.log(dragons.filter(s => s.includes('John')));

// #3) Create a function that calulates the power of 100 of a number entered as a parameter
const power100 = x => x**100;
