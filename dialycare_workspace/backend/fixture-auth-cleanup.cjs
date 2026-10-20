"use strict";
module.exports=function deleteFreshFixtureAccount(auth,credentials,expectedUid){
 const fresh=auth('signInWithPassword',{...credentials,returnSecureToken:true});
 if(fresh.localId!==expectedUid)throw Error('Fixture reauthentication identity mismatch; deletion stopped.');
 auth('delete',{idToken:fresh.idToken});
};
