//=========================================================================================
// - When inserting change owner for Fisioterapeuta
// - Share with Fisioterapeuta Aux so both can insert sessoes.
// - Updates lastSessionDate on Client level (JoaoDias/14-01-2015)
// - STOP updating client convention based on serie convention - (JoaoDias/15-01-2015)
// Revision:   JTD 03/05/2017 - Change children session recordtype accordingly; that is, if serie recordtype changes, children recordtype is changed as well
// Revision:   JTD 30/06/2017 - Detect if serie is cloned from another serie and uncheck the need cloning field in source serie for all
// Revision:   JTD 03/07/2017 - Share series with Ligia when prescription is requested
// Revision:   JTD 13/07/2017 - Save date and author of New Serie request
// Revision:   JTD 27/07/2017 - Delete date and author when New Serie request is cancelled
// Revision:   JTD 30/10/2017 - Minutes calculation based on start and end times
// Revision:   JTD 18/11/2017 - Redesign apex sharing for Physios once it was deleting the sharing for Doctors
// Revision:   JTD 26/11/2017 - Stop changing ownership on parent client (line 162)
// Revision:   JTD 19/06/2018 - ICDs validation
// Revision:   JTD 03/12/2020 - Update Consumed hours on CVPMaster serie
//=========================================================================================


trigger Serie on Serie__c (before insert, before update, after insert, after update, before delete) {
    
        
    if(!SerieHelper.getUserByPassTriggers()){

        Id userRoleFisioId  = SerieHelper.getUserRoleFisioId();
        Id userRoleCeoId    = SerieHelper.getUserRoleCEOId();
    
    //Deletes Pattern SerieTreatments before deleting the Serie itself
    if(Trigger.isBefore && Trigger.isDelete){
        List<SerieTreatment__c> lstSerieTreatment2Delete = new List<SerieTreatment__c>();
        for(Serie__c s: [select (select id from SerieTreatments__r) from Serie__c where id in :Trigger.old]){
            lstSerieTreatment2Delete.addAll(s.SerieTreatments__r);  
        }
        delete lstSerieTreatment2Delete;
    }
    else {//before insert, before update, after insert, after update,
        //THIS BLOCK OF CODE WAS IN THE TOP OF FILE. RETURNS AN ERROR WHEN DELETING COS THERE IS NO TRIGGER.NEW
        Set<Id> ClienteIdsSet = new Set<Id>();
        for(Serie__c s:Trigger.new){
            ClienteIdsSet.add(s.cliente__c);
        }
        List<Id> ClienteIdsLs = new List<Id>(ClienteIdsSet);
        Map<id,cliente__c> parentClientes = new Map<id,cliente__c>([select falecido__c, validity__c from cliente__c where id in :ClienteIdsLs]);        
        
        if(Trigger.isBefore){//before insert and before update
            //JTD 28-02-2016 Fill Lookups to Cliente allowing several related lists each one by treatment type
            for(Serie__c s:Trigger.new){
                s.TTFisioterapia__c = s.TTEnfermagem__c = s.TTApoioHAD__c = s.TTFala__c =  s.TTConsulta__c = s.TTConsultaEnfermagem__c = s.TTOcupacional__c = s.TTHigiene__c = s.TTAluguer__c = s.TTVenda__c = null;
                if(s.Type__c == 'Fisioterapia' || s.Type__c == 'Osteopatia'){
                    s.TTFisioterapia__c = s.Cliente__c; 
                } 
                else if(s.Type__c == 'Enfermagem'){
                    s.TTEnfermagem__c = s.Cliente__c; 
                }                
                else if(s.Type__c == 'Apoio H/AD'){
                    s.TTApoioHAD__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Terapia da Fala'){
                    s.TTFala__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Aluguer'){
                    s.TTAluguer__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Venda'){
                    s.TTVenda__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Higiene'){
                    s.TTHigiene__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Consulta'){
                    s.TTConsulta__c = s.Cliente__c; 
                }                
                else if(s.Type__c == 'Consulta de Enfermagem'){
                    s.TTConsultaEnfermagem__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Terapia Ocupacional'){
                    s.TTOcupacional__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Psicologia'){
                    s.TTPsicologia__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Podologia'){
                    s.TTPodologia__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Nutricao'){
                    s.TTNutricao__c = s.Cliente__c; 
                }
                else if(s.Type__c == 'Analises Clinicas'){
                    s.TTAnalysis__c = s.Cliente__c;
                    //set therapyst price to ZERO when type is Análises Clinicas
                    //s.TherapystSeriePayment__c = 0;
                }                 
            //calculates minutes between start and end times
                if(s.StartTime__c != null && s.EndTime__c != null){
                    system.debug('###'+s);            	
                        s.minutesCalc__c = RCG_Utils.minutesCalc(RCG_Utils.diffTime(s.EndTime__c,s.StartTime__c));
                }
                else s.minutesCalc__c = null;
    
                //JTD 19/06/2018 ICDs validation for CTT-MEDIS
                /*
                if(s.Convencao__c == 'a01D000000u1Pn8'){
                    String query = 'select count(id) counter from ICD__c where name in (\'' + s.IDCs__c.replace(',','\',\'') + '\')';
                    AggregateResult counter = Database.query(query);
                    if(Integer.valueOf(counter.get('counter')) != s.IDCs__c.split(',').size()){
                        s.IDCs__c.addError('Este campo contém 1 ou mais ICDs inválidos. Por favor corrija.');
                    }
                }*/            
            }//end for
        
            if(Trigger.isInsert){//before insert
                Set<Id> clonedSeriesSet = new Set<Id>();
                for(Serie__c s:Trigger.new){
                //copy card validity
                    s.validity__c = parentClientes.get(s.cliente__c).validity__c;                    
                //assign owner with fisioterapeuta which is 
                    if(userInfo.getUserRoleId()== userRoleCEOId || userInfo.getUserRoleId()== userRoleFisioId){
                        s.OwnerId = userInfo.getUserId();
                    }
                //JTD 30/06/2017 - Detects that this serie was cloned and mark it if it cloning is the result of a new serie request
                    if(s.isClone() && s.needClone__c != '' ){
                        clonedSeriesSet.add(s.getCloneSourceId());
                        //Target serie needs to reset the cloned field (source field = 'Checked')
                        s.needClone__c = '';
                    }
                    //JTD 26/11/2017 - Instanciate days field with 0 (field used on sharing rules)
                    s.days__c = 0;
                //CEO wants to edit serie so bellow section is commented
                //    if(parentClientes.get(s.cliente__c).falecido__c){
                //    	s.addError('Este cliente faleceu!');
                //    }
                }
                //JTD 30/06/2017 - Updates uncheck on needcloning field in source serie.
                List<Serie__c> clonedSeriesLst = new List<Serie__c>();
                for(Id serie: clonedSeriesSet){
                    clonedSeriesLst.add(new Serie__c(id = serie, needClone__c = 'Created'));
                }
                
                update clonedSeriesLst;
            }//End is insert

        
            else if(Trigger.isUpdate){//before update               

                List<Sessao__c> 	lstSessao			= new List<Sessao__c>();
                List<serie__Share> 	lsSh 				= new List<serie__Share>();
                List<serie__Share> 	lsShDelete 			= new List<serie__Share>();
                List<Id> 			ls2Delete 			= new List<Id>();
                
                for(Serie__c s:Trigger.new){
                    //JTD 03/05/2017 - Change children session recordtype accordingly
                    if(s.RecordTypeName__c == 'ADMHAD' && Trigger.oldMap.get(s.id).RecordtypeName__c != 'ADMHAD'){
                        for(Sessao__c ss:[select id from sessao__c where serie__c = :s.id]){
                            ss.RecordtypeId = Schema.SObjectType.Sessao__c.getRecordTypeInfosByName().get('ADM H/AD').getRecordTypeId();
                            lstSessao.add(ss);
                        }
                    }
                    else if(s.RecordTypeName__c != 'ADMHAD' && Trigger.oldMap.get(s.id).RecordtypeName__c == 'ADMHAD'){
                        for(Sessao__c ss:[select id from sessao__c where serie__c = :s.id]){
                            ss.RecordtypeId = Schema.SObjectType.Sessao__c.getRecordTypeInfosByName().get('Standard').getRecordTypeId();
                            lstSessao.add(ss);
                        }                  
                    }
                    //JTD 13/07/2017 - Save date and author of New Serie requested by a Phisiotherapyst
                    //or When RCG is requesting straight 
                    if((s.needClone__c == 'Checked' || s.needClone__c == 'Requested'  )&& Trigger.oldMap.get(s.id).needClone__c == null){
                        s.needCloneDate__c = Date.today();
                        s.NeedCloneAuthor__c = (UserInfo.getFirstName()!=null?UserInfo.getFirstName() + ' ':'') +UserInfo.getLastName();
                    }
                    //JTD 27/07/2017 - Delete date and author when New Serie request is cancelled
                    else if(s.needClone__c == null && Trigger.oldMap.get(s.id).needClone__c != null){
                        s.needCloneDate__c 		= null;
                        s.NeedCloneAuthor__c 	= null;
                    }
                    
                    if(s.Type__c != Trigger.oldMap.get(s.id).Type__c){
                        //If there is at least one treatment Pattern
                        if([select count() from SerieTreatment__c where Serie__c = :trigger.oldMap.get(s.id).Id] > 0){
                            s.addError('Não pode mudar o tipo de Tratamento quando já existem Tratamentos definidos para a série');        
                        }
                    }
                    //JTD 2021-12-09 Block changing convention if there is at leas a pattern SerieTreatment 
                    if(s.Convencao__c != Trigger.oldMap.get(s.id).Convencao__c){
                        //If there is at least one treatment Pattern
                        if([select count() from SerieTreatment__c where Serie__c = :trigger.oldMap.get(s.id).Id] > 0){
                            s.addError('Não pode mudar a Convenção quando já existem Tratamentos definidos para a série');        
                        }
                    }                    
                    
                                   
                }
                update lstSessao;
            }
	}
	else if(trigger.isAfter){
        if(trigger.isUpdate){
            Boolean	updateSCVPParentENF 	= false;
            Boolean	updateSCVPParentHAD 	= false;            
    		for(Serie__c s:Trigger.new){    
        //2020-12-03 JTD Updates HoursConsumed field on CVPMaster Serie ('a014G00001RaPhO' = Id of CVP convention)
            	if(s.convencao__c == 'a014G00001RaPhO' && s.HoursSession__c  != trigger.oldMap.get(s.id).HoursSession__c && s.RecordTypeName__c != 'CVPMaster'){
                    if(s.Type__c == 'Enfermagem'){
                        updateSCVPParentENF = true;
                    }
                    else if(s.Type__c == 'Apoio H/AD'){
                        updateSCVPParentHAD = true;
                    }                        
            	}
            }

        //2023-05-03 Para series SMN ADFA mudar o estado para "Agendar MFR" quando as sessões restante < 4
            Map<Id, Serie__c> mapSeries = new Map<Id, Serie__c>([SELECT Cliente__r.Convencao__r.Name FROM Serie__c WHERE Id IN :Trigger.new AND Cliente__r.Convencao__r.Name = 'SMN ADFA']);
            //List<Serie__c> lstSeriesToUpdate = new List<Serie__c>();
    		for(Serie__c s:Trigger.new){
                if(mapSeries.get(s.Id)!= null && s.Sessoes_Restantes__c <= 4 && trigger.oldMap.get(s.id).Sessoes_Restantes__c > 4){
                    // lstSeriesToUpdate.add( new Serie__c(
                    //         Id              = s.Id,
                    //         NeedClone__c    = 'Agendar MFR'
                    //     )
                    // );
                    s.NeedClone__c = 'Agendar MFR';
                }
            }
            // if(!lstSeriesToUpdate.isEmpty()){
            //     SerieHelper.byPassTriggers = true;
            //     update lstSeriesToUpdate;
            //     SerieHelper.byPassTriggers = false;
            // }            

        

        //2020-12-03 JTD Updates HoursConsumed field on CVPMaster Serie for Enfermagem
        /*
            if(updateSCVPParentENF == true){
                AggregateResult  agg1 = [select SUM(HoursSession__c)  total from Serie__c where convencao__r.name ='CVP' and RecordTypeName__c <> 'CVPMaster' and Type__c = 'Enfermagem'];
                AggregateResult  agg2 = [select SUM(HoursConsumed__c) total from Serie__c where convencao__r.name ='CVP' and RecordTypeName__c <> 'CVPMaster' and Type__c = 'Enfermagem'];
                Serie__c sCVPParent = [select id from Serie__c where RecordTypeName__c = 'CVPMaster' and Type__c = 'Enfermagem'];
                sCVPParent.HoursRecordedOnChildren__c = (Decimal)agg1.get('total');
                sCVPParent.HoursConsumedOnChildren__c = (Decimal)agg2.get('total');
                update sCVPParent;
            }
        //2020-12-03 JTD Updates HoursConsumed field on CVPMaster Serie for Apoio H/AD
            if(updateSCVPParentHAD == true){
                AggregateResult  agg1 = [select SUM(HoursSession__c)  total from Serie__c where convencao__r.name ='CVP' and RecordTypeName__c <> 'CVPMaster' and Type__c = 'Apoio H/AD'];
                AggregateResult  agg2 = [select SUM(HoursConsumed__c) total from Serie__c where convencao__r.name ='CVP' and RecordTypeName__c <> 'CVPMaster' and Type__c = 'Apoio H/AD'];
                Serie__c sCVPParent = [select id from Serie__c where RecordTypeName__c = 'CVPMaster' and Type__c = 'Apoio H/AD'];
                sCVPParent.HoursRecordedOnChildren__c = (Decimal)agg1.get('total');
                sCVPParent.HoursConsumedOnChildren__c = (Decimal)agg2.get('total');
                update sCVPParent;
            }
           */             
        }
		//====================================================================================================================================
		//Updates Cliente checkBox particulares if there is a children serie as particular
		//Controls if RollUp field lastSessionDate changed. If so, updates lastSessionDate at Client Level
		//====================================================================================================================================
        Map<Id,Boolean> clientParticularSometimes = new Map<Id,Boolean>();
        Map<Id,Date> clientLastSessionDate = new Map<Id,Date>();
        //Iterate to create the Map with lastSessionDate by parentClient and to map boolean particular series in Client
        for(Serie__c s:[select lastSessionDate__c, cliente__c, convencao__r.name from serie__c where cliente__c in :ClienteIdsLs]){
            if(clientParticularSometimes.get(s.cliente__c) == null){
                clientParticularSometimes.put(s.cliente__c, s.convencao__r.name=='PARTIC'?true:false);
            } else if(s.convencao__r.name == 'PARTIC'){
                        clientParticularSometimes.put(s.cliente__c, true);
            }
            if((clientLastSessionDate.get(s.cliente__c) == null) || (s.lastSessionDate__c > clientLastSessionDate.get(s.cliente__c))){
                clientLastSessionDate.put(s.cliente__c, s.lastSessionDate__c);
            }
            system.debug(clientParticularSometimes);
            system.debug(clientLastSessionDate);
        }
        //Instaciate lastSessionDate on all parent clients
        for(Cliente__c c: parentClientes.values()){
            c.lastSessionDate__c = clientLastSessionDate.get(c.id);
            c.hasParticularSeries__c = clientParticularSometimes.get(c.id);
            system.debug(parentClientes.values());
        }
        update parentClientes.values();		
        if(userinfo.getProfileId() != SerieHelper.getUserProfileId()){
//==================================================================================================================================		
// It updates client convention, that is, client convention is controlled by serie convention;it updates client ownerid as well. WHY? (turned off at 2017-11-26)
// STOP updating client convention based on serie convention - 15/01/2015 - Client convention is fixed. New checkbox to sign particular series.
//==================================================================================================================================
        Map<ID,Serie__c>  msObj = new Map<ID,Serie__c>([select id, cliente__c, ownerId from serie__c where id in :Trigger.new]);
        Map<ID,ID> mc = new Map<ID,ID>();
//builds a map serieID -> clienteID
        for(ID i: msObj.keyset()) mc.put(i,msObj.get(i).cliente__c);
//builds a map clienteId -> cliente__c
        Map<ID,Cliente__c> mcObj = new Map<ID,Cliente__c>([select id, convencao__c from cliente__c where id in :mc.values()]);
        for(Serie__c s:Trigger.new){
//STOP updating client convention based on serie convention 
//mcObj.get(mc.get(s.id)).convencao__c = s.convencao__c;
            system.debug(s.id);
            system.debug(mc.get(s.id));
            system.debug(mcObj.get(mc.get(s.id)));
            system.debug(s.ownerid);
            //mcObj.get(mc.get(s.id)).ownerId = s.ownerId;
        }
        update mcObj.values();	
    //====================================================================================================================================		
    //Create apex sharing for fisioterapeutas (fisioterapeuta2 is optional)
    //====================================================================================================================================
    //Reset manual sharing to add from scratch apex for physios (exclude reset for Doctors)
        Map<Id,User> mapDoctors = new Map<Id,User>([select id from User where profileId in (select id from Profile where name = 'Doctor')]);
        delete [select id from serie__Share where parentId in :Trigger.new and rowcause = 'Manual' and UserOrGroupId in (select id from User where not id in :mapDoctors.keySet())];
    //ensure that users are not inactive, otherwise it causes an exception
        Map<ID,User> activeUserIDs = new Map<ID,User>([select id from user where isActive = true]);
        List<serie__Share> 	lsShTherapyst 	= new List<serie__Share>();
        List<serie__Share> 	lsShDoctor		= new List<serie__Share>();
        List<serie__Share> 	lsShDelete 		= new List<serie__Share>();
        List<Id> 			ls2Delete 		= new List<Id>();                
        for(Serie__c s:Trigger.new){
            //checks if owner is active and add sharing to auxilary therapysts
            if(activeUserIDs.keySet().contains(s.ownerID)){
                if(s.Fisioterapeuta__c != s.ownerId && activeUserIDs.keySet().contains(s.Fisioterapeuta__c)){
                    serie__Share sSh = new serie__Share(); 
                    sSh.ParentId = s.Id;
                    sSh.UserOrGroupId = s.Fisioterapeuta__c;
                    sSh.AccessLevel = 'Read';
                    lsShTherapyst.add(sSh);
                }				        
                if(s.Fisioterapeuta2__c != null && s.Fisioterapeuta2__c != s.ownerId && activeUserIDs.keySet().contains(s.Fisioterapeuta2__c)){
                    serie__Share sSh2 = new serie__Share(); 
                    sSh2.ParentId = s.Id;
                    sSh2.UserOrGroupId = s.Fisioterapeuta2__c;
                    sSh2.AccessLevel = 'Read';
                    lsShTherapyst.add(sSh2);
                }
                if(s.Fisioterapeuta3__c != null && s.Fisioterapeuta3__c != s.ownerId && activeUserIDs.keySet().contains(s.Fisioterapeuta3__c)){
                    serie__Share sSh3 = new serie__Share(); 
                    sSh3.ParentId = s.Id;
                    sSh3.UserOrGroupId = s.Fisioterapeuta3__c;
                    sSh3.AccessLevel = 'Read';
                    lsShTherapyst.add(sSh3);
                }                    
            }
            
            //JTD 03/07/2017 - Share series with Doctor when prescription is requested
            //system.debug('###' + s.needClone__c + '#' + Trigger.oldMap.get(s.id).needClone__c);
            if(s.needClone__c == 'Requested' && (Trigger.isUpdate?Trigger.oldMap.get(s.id).needClone__c != 'Requested':true)){
                serie__Share sSh = new serie__Share(); 
                sSh.ParentId = s.Id;
                //Jose Espanca Id
                if(s.RequestedDoctor__c == 'Ligia Jardim'){
                    sSh.UserOrGroupId = '005D0000005uO7O';    
                }
                else if(s.RequestedDoctor__c == 'José Espanca'){
                    sSh.UserOrGroupId = '005D000000Akqi8';
                }
                //New selection based on Doctor on Serie
                /*
                try{
                    sSh.UserOrGroupId = [select id from User where name = :s.Doctor__c][0].id];
                }
                catch(Exception e){
                    //Jose Espanca Id if doctor in serie is not a user in the system
                    sSh.UserOrGroupId = '005D000000Akqi8';                    
                }
                */
                sSh.AccessLevel = 'Read';
                sSh.rowCause	= Schema.Serie__Share.rowCause.Prescription__c;
                system.debug('sSh#'+ sSh);
                lsShDoctor.add(sSh);
            }
            //JTD 03/07/2017 - Delete sharing with Doctor when prescription is executed
            else if(s.needClone__c == 'Prescribed' && Trigger.oldMap.get(s.id).needClone__c == 'Requested'){
                delete [select id from Serie__share where parentId = :s.id and rowCause = 'Prescription__c'];	
            }
        }
        insert lsShTherapyst;
        system.debug(lsshDoctor);
        insert lsShDoctor;
        system.debug(lsshDoctor);
		}
	}
  }
  }
}
