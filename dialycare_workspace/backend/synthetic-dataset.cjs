'use strict';
// Invented combinations for this demonstration only; no external people/data sources.
const seedKey='dialycare-mwf-tths-v1';
const names=[
 'Amelita R. Villacorta','Renato P. Malvar','Lucila B. Panganiban','Edgardo T. Lacsamana',
 'Maricel A. Dumlao','Danilo S. Quimson','Rosalinda M. Abad','Ernesto V. Salonga',
 'Lourdes C. Yambao','Roberto G. Manalo Jr.','Elvira N. Magpantay','Ricardo J. Catacutan',
 'Corazon F. Dizon','Alfredo L. Lansangan','Teresita D. Macaraeg','Rolando A. Sarmiento',
 'Virginia E. Dimaculangan','Emmanuel K. Cabatingan','Estelita U. Baluyot','Rogelio B. Magbanua',
 'Carmelita H. Alonzo','Arturo R. Magsino','Leonora P. Tolentino','Fernando D. Capili',
 'Imelda S. Ocampo','Reynaldo T. Labitoria','Gloria M. Cañete','Nestor V. Gatchalian',
 'Cecilia G. Batac','Armando L. Macapagal','Norma C. Palisoc','Eduardo A. Banzon',
 'Myrna J. Cabalquinto','Benjamin N. Pamintuan','Julieta R. Mallari','Oscar F. Lumibao',
 'Remedios D. Calunod','Wilfredo E. Tapales','Flordeliza B. Mamaril','Antonio M. Camat',
 'Aurora S. Bayani','Crisanto P. Almeda','Erlinda T. Villamor',
];
const relatives=['Patricia','Miguel','Andrea','Paolo','Clarissa','Marco','Daphne','Rafael','Isabel','Gabriel','Bianca','Adrian','Camille','Anton','Kristine','Carlo','Marianne','Luis','Elaine','Martin','Therese','Dominic','Nadine','Vincent','Abigail','Francis','Diana','Philip','Joanna','Lorenzo','Regina','Enrico','Monica','Joaquin','Lara','Angelo','Beatrice','Manuel','Celine','Emilio','Francesca','Julian','Melissa'];
function dataset(){
 return names.map((name,index)=>{
  const n=index+1,surname=name.replace(/ Jr\.$/,'').split(' ').at(-1);
  const group=index<22?'MWF':'TTHS',groupIndex=index<22?index:index-22;
  const patientId=`demo-mwf-tths-v1-p${String(n).padStart(2,'0')}`;
  const relativeId=`demo-mwf-tths-v1-r${String(n).padStart(2,'0')}`;
  return {patient:{id:patientId,name,gender:index%2===0?'Female':'Male',birthDate:`${1958+index%24}-${String(1+index%12).padStart(2,'0')}-${String(1+index%25).padStart(2,'0')}T00:00:00`,contact:'DEMO — not contactable',address:`Fictional Demonstration Area ${String(n).padStart(2,'0')} — not deliverable`,maritalStatus:['Married','Widowed','Single','Separated'][index%4],philHealthNumber:'',heightCm:150+(index*3)%31+0.5,weightKg:48+(index*7)%39+0.2,mdrStatus:'Unknown',bloodType:['A+','O+','B+','AB+'][index%4],medicalNotes:'Synthetic demonstration profile. No clinical diagnosis or treatment is asserted.',treatmentNotes:'',recordStatus:'active',archivedAt:null,archivedBy:null,scheduleGroup:group,room:`Room ${String(groupIndex%6+1).padStart(2,'0')}`,batch:`Batch ${['A','B','C'][Math.floor((groupIndex%18)/6)]}`,demonstrationSeed:seedKey,synthetic:true},relative:{id:relativeId,name:`${relatives[index]} ${surname}`,contact:'DEMO — not contactable',address:'Fictional demonstration address — not deliverable'},relationship:['Daughter','Son','Sister','Brother'][index%4],plannedDurationMinutes:[180,210,240,270,300][index%5],groupIndex};
 });
}
module.exports={seedKey,dataset};
