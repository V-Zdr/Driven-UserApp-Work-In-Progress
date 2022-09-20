import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:users_app/assistants/request_assistant.dart';
import 'package:users_app/dataHandler/app_data.dart';
import 'package:users_app/global/map_key.dart';
import 'package:users_app/models/address.dart';
import 'package:users_app/models/place_predictions.dart';
import 'package:users_app/widgets/divider.dart';
import 'package:users_app/widgets/progress_dialog.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {

  TextEditingController pickupTextEditingController =  TextEditingController();
  TextEditingController dropOffTextEditingController =  TextEditingController();
  List<PlacePredictions> placePredictionsList=[];

  @override
  Widget build(BuildContext context) {
    String placeAddress=Provider.of<AppData>(context).pickupLocation?.placeName ?? "";
    pickupTextEditingController.text=placeAddress;
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 200.0,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                color: Colors.black,
                blurRadius: 6.0,
                spreadRadius: 0.5,
                offset: Offset(0.7,0.7),
              )
          ]
            ),
            child: Padding(
              padding: EdgeInsets.only(left: 25.0,top: 28.0,right: 25.0,bottom: 20.0),
              child: Column(
                children: [
                  SizedBox(height: 5.0,),
                  Stack(
                    children: [
                      GestureDetector(
                          onTap: (){
                            Navigator.pop(context);
                          },
                          child: Icon(Icons.arrow_back)),
                      Center(
                        child: Text("Set drop off",style: TextStyle(fontSize: 18.0),),
                      )
                    ],
                  ),
                  SizedBox(height: 16.0,),
                  Row(
                    children: [
                      Image.asset("images/logo.png",height: 16.0,width: 16.0,),
                      SizedBox(height: 18.0,),
                      Expanded(child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(5.0),

                        ),
                        child: Padding(
                          padding: EdgeInsets.all(3.0),
                          child: TextField(
                            controller: pickupTextEditingController,
                            decoration: InputDecoration(
                              hintText: "Pickup location",
                              fillColor: Colors.white,
                              filled: true,
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.only(left: 11.0,top: 8.0,bottom: 8.0),
                            ),
                          ),
                        ),
                      )),
                    ],
                  ),
                  SizedBox(height: 10.0,),
                  Row(
                    children: [
                      Image.asset("images/logo.png",height: 16.0,width: 16.0,),
                      SizedBox(height: 18.0,),
                      Expanded(child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(5.0),

                        ),
                        child: Padding(
                          padding: EdgeInsets.all(3.0),
                          child: TextField(
                            onChanged: (val){
                              findPlace(val);
                            },
                            controller: dropOffTextEditingController,
                            decoration: InputDecoration(
                              hintText: "Where to?",
                              fillColor: Colors.white,
                              filled: true,
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.only(left: 11.0,top: 8.0,bottom: 8.0),
                            ),
                          ),
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.0,),
          (placePredictionsList.length>0 )?Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0,horizontal: 16.0),
            child: ListView.separated(
              padding: EdgeInsets.all(0.0),
              itemBuilder: (context,index){
                return PredictionTile(placePredictions: placePredictionsList[index],);
              },
              separatorBuilder: (BuildContext context, int index)=>DividerWidget(),
              itemCount: placePredictionsList.length,
              shrinkWrap: true,
              physics: ClampingScrollPhysics(),
            ),
          ) : Container(

          )
        ],
      ),
    );
  }
    void findPlace(String placeName)async{
      if(placeName.length>1){
        String autoCompleteUrl="https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${placeName}&types=geocode&key=${mapKey}&components=country:mk";
        var res = await RequestAssistant.getRequest(autoCompleteUrl);
        if(res=="failed"){
          return;
        }
          if(res["status"]=="OK"){
            var predictions=res["predictions"];
            var placesList=(predictions as List).map((e) => PlacePredictions.fromJson(e)).toList();
            setState(() {
              placePredictionsList=placesList;
            });
        }
      }
  }
}

class PredictionTile extends StatelessWidget {
  final PlacePredictions? placePredictions;
  const PredictionTile({Key? key,this.placePredictions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed:(){
        getPlaceAddressDetails(placePredictions?.place_id as String, context);
      },
      child: Container(
        child: Column(
          children: [
            SizedBox(width: 10.0,),
            Row(
              children: [
                Icon(Icons.add_location),
                SizedBox(width: 14.0,),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.0,),
                      Text(placePredictions?.main_text as String,overflow: TextOverflow.ellipsis,style: TextStyle(fontSize: 16.0),),
                      SizedBox(height: 2.0,),
                      Text(placePredictions?.secondary_text as String,overflow: TextOverflow.ellipsis,style: TextStyle(fontSize: 14.0,color: Colors.grey),),
                      SizedBox(height: 8.0,),
                    ],
                  ),
                )
              ],
            ),
            SizedBox(width: 14.0,),
          ],
        ),
      ),
    );
  }
  void getPlaceAddressDetails(String placeId,context)async{

    showDialog(context: context, builder: (BuildContext context)=>ProgressDialog(message: "Setting drop off, please wait...",));

    String placeDetailsUrl="https://maps.googleapis.com/maps/api/place/details/json?&place_id=${placeId}&key=${mapKey}";
    var res = await RequestAssistant.getRequest(placeDetailsUrl);

    Navigator.pop(context);
    if(res=="failed"){
      return;
    }
    if(res["status"]=="OK"){
      Address address=Address();
      address.placeName=res["result"]["name"];
      address.placeId=placeId;
      address.latitude=res["result"]["geometry"]["location"]["lat"];
      address.longitude=res["result"]["geometry"]["location"]["lng"];

      Provider.of<AppData>(context,listen: false).updateDropOffLocation(address);
      Navigator.pop(context,"obtainedDirections");
    }
  }
}

